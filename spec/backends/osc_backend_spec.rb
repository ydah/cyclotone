# frozen_string_literal: true

RSpec.describe Cyclotone::Backends::OSCBackend do
  let(:sent_packets) { [] }
  let(:socket) do
    Class.new do
      def initialize(sent_packets)
        @sent_packets = sent_packets
      end

      def send(packet, _flags, host, port)
        @sent_packets << { packet: packet, host: host, port: port }
      end
    end.new(sent_packets)
  end

  it "builds SuperDirt-style payloads and sends packets" do
    backend = described_class.new(socket: socket)
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { s: "bd", gain: 0.8 }
    )

    expect(backend.payload_for(event, at: 12.5)).to include("s", "bd", "gain", 0.8)

    backend.send_event(event, at: 12.5)

    expect(sent_packets.length).to eq(1)
    expect(sent_packets.first[:host]).to eq("127.0.0.1")
    expect(sent_packets.first[:port]).to eq(57_120)
  end
end
