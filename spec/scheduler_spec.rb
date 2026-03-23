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
end
