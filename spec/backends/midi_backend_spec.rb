# frozen_string_literal: true

RSpec.describe Cyclotone::Backends::MIDIBackend do
  let(:messages) { [] }
  let(:output) { ->(message) { messages << message } }

  it "builds note on/off messages" do
    backend = described_class.new(output: output)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: 60, velocity: 100, sustain: 0.25 }
    )

    expect(backend.messages_for(event).map { |message| message[:type] }).to eq(%i[note_on note_off])
    expect(backend.messages_for(event).first[:velocity]).to eq(100)

    backend.send_event(event, at: 10.0)

    expect(messages.length).to eq(2)
  end

  it "builds control change messages" do
    backend = described_class.new(output: output)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { cc: { 74 => 90 }, channel: 2 }
    )

    expect(backend.messages_for(event)).to eq([
      { type: :cc, channel: 2, controller: 74, value: 90 }
    ])
  end
end
