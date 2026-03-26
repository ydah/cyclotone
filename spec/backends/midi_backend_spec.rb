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

  it "lists and selects available MIDI outputs when UniMIDI is present" do
    first = Struct.new(:name).new("Device A")
    second = Struct.new(:name).new("Device B")
    unimidi_output = Class.new do
      def self.all
        [Struct.new(:name).new("Device A"), Struct.new(:name).new("Device B")]
      end
    end
    stub_const("UniMIDI", Module.new)
    stub_const("UniMIDI::Output", unimidi_output)

    expect(described_class.available_outputs.map(&:name)).to eq(["Device A", "Device B"])
    expect(described_class.new(device_name: "Device B").instance_variable_get(:@output)&.name).to eq("Device B")
    expect(described_class.new.instance_variable_get(:@output)&.name).to eq(first.name)
    expect(described_class.new(device_name: "Missing").instance_variable_get(:@output)).to be_nil
  end
end
