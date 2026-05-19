# frozen_string_literal: true

RSpec.describe "backend send_event contract" do
  let(:event) do
    Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { note: 60, s: "bd", sustain: 0.1 }
    )
  end

  it "is implemented by null, osc, midi, and midi file backends" do
    packets = []
    socket = Class.new do
      def initialize(packets)
        @packets = packets
      end

      def send(packet, *_args)
        @packets << packet
      end
    end.new(packets)
    midi_messages = []
    backends = [
      Cyclotone::Backends::NullBackend.new,
      Cyclotone::Backends::OSCBackend.new(socket: socket),
      Cyclotone::Backends::MIDIBackend.new(output: ->(message) { midi_messages << message }),
      Cyclotone::Backends::MIDIFileBackend.new(path: File.join(Dir.pwd, "tmp", "contract.mid"))
    ]

    backends.each do |backend|
      expect(backend.send_event(event, at: 1.0, cps: 1, slot_id: :d1)).to be_truthy
      expect(backend.flush).to be_truthy if backend.respond_to?(:flush)
      expect(backend.panic).to be_truthy if backend.respond_to?(:panic)
      expect(backend.close).to be_truthy if backend.respond_to?(:close)
    end
  end
end
