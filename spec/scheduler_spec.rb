# frozen_string_literal: true

RSpec.describe Cyclotone::Scheduler do
  let(:events) { [] }
  let(:backend) { Class.new { define_method(:initialize) { |events| @events = events }; define_method(:send_event) { |event, at:| @events << { event: event, at: at } } }.new(events) }

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
end
