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

  it "expands note arrays into chord messages" do
    backend = described_class.new(output: output)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: [60, 64], velocity: 100, release_velocity: 12, sustain_cycles: 1 }
    )

    messages = backend.messages_for(event, cps: 2)

    expect(messages.map { |message| message[:note] }).to eq([60, 60, 64, 64])
    expect(messages.select { |message| message[:type] == :note_off }.map { |message| message[:velocity] }).to eq([12, 12])
    expect(messages.select { |message| message[:type] == :note_off }.map { |message| message[:delay] }).to eq([0.5, 0.5])
  end

  it "emits control changes in controller order" do
    backend = described_class.new(output: output)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { cc: { 74 => 90, 1 => 20 }, channel: 2 }
    )

    expect(backend.messages_for(event).map { |message| message[:controller] }).to eq([1, 74])
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

  it "sends raw MIDI bytes to UniMIDI-style outputs" do
    sent = []
    device = Class.new do
      def initialize(sent)
        @sent = sent
      end

      def open
        yield self
      end

      def puts(bytes)
        @sent << bytes
      end
    end.new(sent)

    backend = described_class.new(output: device)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: 60, velocity: 100, sustain: 0.25, channel: 1 }
    )

    backend.send_event(event, at: 10.0)

    expect(sent).to include([0x91, 60, 100], [0x81, 60, 0])
  end

  it "can require an explicit output" do
    backend = described_class.new(device_name: "__missing__", strict_output: true)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: 60 }
    )

    expect { backend.send_event(event, at: 0.0) }.to raise_error(Cyclotone::ConnectionError, /output/)
  end

  it "queues scheduled messages on a single worker" do
    backend = described_class.new(output: output, schedule: true)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: 60, sustain: 0.25 }
    )

    backend.send_event(event, at: Time.now.to_f + 60)

    expect(backend.instance_variable_get(:@scheduled_messages).length).to eq(2)
    expect(backend.instance_variable_get(:@scheduler_thread)).to be_alive

    backend.close
  end

  it "sends panic controller messages" do
    backend = described_class.new(output: output)

    backend.panic

    expect(messages.count { |message| message[:controller] == 123 }).to eq(16)
    expect(messages.count { |message| message[:controller] == 120 }).to eq(16)
  end
end
