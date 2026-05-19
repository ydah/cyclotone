# frozen_string_literal: true

RSpec.describe Cyclotone::Scheduler do
  let(:events) { [] }
  let(:backend) do
    Class.new do
      define_method(:initialize) { |events| @events = events }
      define_method(:send_event) { |event, at:, **options| @events << { event: event, at: at, options: options } }
    end.new(events)
  end

  it "schedules lookahead events for registered patterns" do
    scheduler = described_class.new(cps: 1, backend: backend, lookahead: 0.5, interval: 0.01)
    scheduler.update_pattern(:d1, Cyclotone::Controls.s("bd"))

    now = scheduler.send(:monotonic_time)
    scheduler.tick(now + 0.1)

    expect(events).not_to be_empty
    expect(events.first[:event].value).to include(s: "bd")
  end

  it "renders exact durations without lookahead spill" do
    scheduler = described_class.new(cps: 1, backend: backend, lookahead: 0.5, interval: 0.01)
    scheduler.update_pattern(:d1, Cyclotone::Controls.s("bd hh"))

    scheduler.render(duration: 0.25)

    expect(events.length).to eq(1)
    expect(events.first[:event].value).to include(s: "bd")
  end

  it "keeps the logical cycle continuous when cps changes" do
    scheduler = described_class.new(cps: 1, backend: backend, lookahead: 0.5, interval: 0.01)
    allow(Time).to receive(:now).and_return(Time.at(1_000))
    allow(scheduler).to receive(:monotonic_time).and_return(100.0)

    scheduler.set_cycle(0)

    allow(Time).to receive(:now).and_return(Time.at(1_000.5))
    allow(scheduler).to receive(:monotonic_time).and_return(100.5)

    scheduler.setcps(2)
    expect(scheduler.current_cycle).to be_within(1e-6).of(0.5)

    allow(scheduler).to receive(:monotonic_time).and_return(101.0)

    expect(scheduler.current_cycle).to be_within(1e-6).of(1.5)
  end

  it "rejects non-positive cps values" do
    scheduler = described_class.new(cps: 1, backend: backend)

    expect { described_class.new(cps: 0, backend: backend) }.to raise_error(ArgumentError, /cps/)
    expect { scheduler.setcps(-1) }.to raise_error(ArgumentError, /cps/)
  end

  it "cleans sent keys when a pattern is removed" do
    scheduler = described_class.new(cps: 1, backend: backend, lookahead: 0.5, interval: 0.01)
    scheduler.update_pattern(:d1, Cyclotone::Controls.s("bd"))

    scheduler.render(duration: 0.25)
    expect(scheduler.instance_variable_get(:@sent)).not_to be_empty

    scheduler.remove_pattern(:d1)

    expect(scheduler.instance_variable_get(:@sent)).to be_empty
  end

  it "logs slot ids and retries failed events when configured" do
    log_messages = []
    attempts = 0
    failing_backend = Class.new do
      define_method(:initialize) { |attempts_ref| @attempts_ref = attempts_ref }
      define_method(:send_event) do |*_args, **_options|
        @attempts_ref.call
        raise "send failed"
      end
    end.new(-> { attempts += 1 })
    scheduler = described_class.new(cps: 1, backend: failing_backend, logger: ->(message) { log_messages << message }, retry_failed: true)
    scheduler.update_pattern(:lead, Cyclotone::Controls.s("bd"))

    scheduler.render(duration: 0.25)
    scheduler.render(duration: 0.25)

    expect(attempts).to eq(2)
    expect(log_messages.join).to include("slot=lead")
    expect(scheduler.last_error.message).to eq("send failed")
  end

  it "tracks scheduler tick metrics" do
    scheduler = described_class.new(cps: 1, backend: backend)

    scheduler.send(:record_tick_duration, 0.01)

    expect(scheduler.metrics).to include(ticks: 1, last_tick_duration: 0.01, max_tick_duration: 0.01)
  end

  it "closes the capture protocol during render" do
    capture_backend = Class.new do
      attr_reader :calls

      def initialize
        @calls = []
      end

      def begin_capture(at:)
        @calls << [:begin_capture, at]
      end

      def send_event(*)
        @calls << [:send_event]
      end

      def end_capture
        @calls << [:end_capture]
      end

      def write!
        @calls << [:write]
      end
    end.new
    scheduler = described_class.new(cps: 1, backend: capture_backend)
    scheduler.update_pattern(:d1, Cyclotone::Controls.s("bd"))

    scheduler.render(duration: 0.25)

    expect(capture_backend.calls.map(&:first)).to eq(%i[begin_capture send_event end_capture write])
  end

  it "uses a logical origin for offline render timestamps" do
    scheduler = described_class.new(cps: 2, backend: backend)
    scheduler.update_pattern(:d1, Cyclotone::Controls.s("bd sd"))

    scheduler.render(duration: 0.5, at: 12.0)

    expect(events.map { |entry| entry[:at] }).to eq([12.0, 12.25])
  end

  it "supports injected clocks for deterministic scheduling" do
    clock = Class.new do
      attr_accessor :monotonic, :wall

      def initialize
        @monotonic = 10.0
        @wall = 100.0
      end

      def monotonic_time
        monotonic
      end

      def wall_time
        wall
      end
    end.new
    scheduler = described_class.new(cps: 1, backend: backend, lookahead: 0.25, clock: clock)
    scheduler.update_pattern(:d1, Cyclotone::Controls.s("bd"))

    scheduler.tick(clock.monotonic)

    expect(events.first[:at]).to eq(100.0)
  end

  it "supports cycle-based lookahead and interval values" do
    clock = Class.new do
      def monotonic_time = 10.0
      def wall_time = 100.0
    end.new
    scheduler = described_class.new(cps: 2, backend: backend, lookahead_cycles: 1, interval_cycles: 0.5, clock: clock)
    scheduler.update_pattern(:d1, Cyclotone::Controls.s("bd sd"))

    scheduler.tick(10.0)

    expect(events.map { |entry| entry[:event].value[:s] }).to eq(%w[bd sd])
    expect(scheduler.send(:current_interval)).to eq(0.25)
  end

  it "supports slot-local cps scaling" do
    scheduler = described_class.new(cps: 1, backend: backend)
    scheduler.update_pattern(:lead, Cyclotone::Controls.s("bd sd"), cps: 2)

    scheduler.render(duration: 0.5)

    expect(events.map { |entry| entry[:event].value[:s] }).to eq(%w[bd sd])
    expect(events.map { |entry| entry[:event].onset }).to eq([0, Rational(1, 4)])
  end

  it "handles concurrent lifecycle and pattern updates" do
    scheduler = described_class.new(cps: 1, backend: Cyclotone::Backends::NullBackend.new, interval: 0.001)
    worker_threads = 4.times.map do |index|
      Thread.new do
        20.times do |step|
          scheduler.update_pattern(:"d#{index}", Cyclotone::Controls.s(step.even? ? "bd" : "sd"))
          scheduler.setcps(1 + (step % 3))
          scheduler.current_cycle
        end
      end
    end
    lifecycle_thread = Thread.new do
      8.times do
        scheduler.start
        sleep(0.001)
        scheduler.stop
      end
    end

    (worker_threads + [lifecycle_thread]).each(&:value)
    scheduler.stop

    expect(scheduler.running?).to be(false)
    expect(scheduler.last_error).to be_nil
  end
end
