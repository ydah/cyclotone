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
end
