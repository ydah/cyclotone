# frozen_string_literal: true

RSpec.describe Cyclotone::Backends::NullBackend do
  it "captures and flushes events" do
    backend = described_class.new
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: "bd"
    )

    backend.send_event(event, at: 1.0, cps: 1)
    expect(backend.events.length).to eq(1)

    backend.flush
    expect(backend.events).to eq([])
  end
end
