# frozen_string_literal: true

require "fileutils"

RSpec.describe Cyclotone::Backends::MIDIFileBackend do
  let(:output_path) { File.join(Dir.pwd, "tmp", "spec-midi-output.mid") }

  after do
    FileUtils.rm_f(output_path)
  end

  it "encodes note and control events into a midi file" do
    backend = described_class.new(path: output_path, bpm: 120, channel: 2)
    note_event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: 60, velocity: 100, sustain: 0.25 }
    )
    cc_event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { cc: { 74 => 90 }, channel: 1 }
    )

    backend.begin_capture(at: 10.0)
    backend.send_event(note_event, at: 10.5)
    backend.send_event(cc_event, at: 10.75)

    data = backend.midi_file_data

    expect(data).to start_with("MThd".b)
    expect(data).to include("MTrk".b)
    expect(data).to include("\xFF\x51\x03".b)
    expect(data).to include("\xFF\x58\x04".b)
    expect(data).to include([0x92, 60, 100].pack("C3"))
    expect(data).to include([0x82, 60, 0].pack("C3"))
    expect(data).to include([0xB1, 74, 90].pack("C3"))
  end

  it "writes the midi file to disk" do
    backend = described_class.new(path: output_path, bpm: 120)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: 64, velocity: 0.5, sustain: 0.25 }
    )

    backend.send_event(event, at: 0.0)
    backend.write!

    expect(File.exist?(output_path)).to be(true)
    expect(File.binread(output_path)).to start_with("MThd".b)
  end

  it "derives bpm from scheduler cps" do
    expect(described_class.bpm_from_cps(0.5, beats_per_cycle: 4)).to eq(120.0)
  end

  it "writes when used through scheduler render" do
    backend = described_class.new(path: output_path, bpm: 120)
    scheduler = Cyclotone::Scheduler.new(cps: 1, backend: backend)
    scheduler.update_pattern(:d1, Cyclotone::Controls.note(60))

    scheduler.render(duration: 0.25)

    expect(File.exist?(output_path)).to be(true)
  end

  it "can split rendered events into slot tracks" do
    backend = described_class.new(path: output_path, bpm: 120, track_mode: :slot)
    scheduler = Cyclotone::Scheduler.new(cps: 1, backend: backend)
    scheduler.update_pattern(:d1, Cyclotone::Controls.note(60))
    scheduler.update_pattern(:d2, Cyclotone::Controls.note(64))

    scheduler.render(duration: 0.25)
    data = backend.midi_file_data

    expect(data[8, 2].unpack1("n")).to eq(1)
    expect(data[10, 2].unpack1("n")).to eq(2)
    expect(data).to include("Cyclotone:d1")
    expect(data).to include("Cyclotone:d2")
  end
end
