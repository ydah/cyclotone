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

    expect(backend.payload_for(event, at: 12.5, cps: 2)).to include(
      "when", 12.5,
      "onset", 12.5,
      "offset", 13.0,
      "s", "bd",
      "gain", 0.8
    )

    backend.send_event(event, at: 12.5, cps: 2)

    expect(sent_packets.length).to eq(1)
    expect(sent_packets.first[:host]).to eq("127.0.0.1")
    expect(sent_packets.first[:port]).to eq(57_120)
  end

  it "reconnects and retries after a socket failure" do
    attempts = 0
    replacement_packets = []
    replacement_socket = Class.new do
      def initialize(sent_packets)
        @sent_packets = sent_packets
      end

      def send(packet, _flags, host, port)
        @sent_packets << { packet: packet, host: host, port: port }
      end
    end.new(replacement_packets)

    flaky_socket = Class.new do
      attr_reader :closed

      def initialize
        @closed = false
      end

      def send(*)
        raise IOError, "socket closed"
      end

      def close
        @closed = true
      end
    end.new

    backend = described_class.new(
      socket: flaky_socket,
      retries: 1,
      socket_factory: lambda {
        attempts += 1
        replacement_socket
      }
    )
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { s: "bd" }
    )

    backend.send_event(event, at: 3.5)

    expect(flaky_socket.closed).to be(true)
    expect(attempts).to eq(1)
    expect(replacement_packets.length).to eq(1)
  end

  it "supports custom addresses and OSC literal types" do
    backend = described_class.new(socket: socket, address: "/cyclotone/play")
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 1),
      part: Cyclotone::TimeSpan.new(0, 1),
      value: { enabled: true, muted: false, absent: nil, mode: :lead }
    )

    message = backend.build_message(event, at: 1.0)

    expect(message).to include("/cyclotone/play")
    expect(backend.send(:osc_type_tag, true)).to eq("T")
    expect(backend.send(:osc_type_tag, false)).to eq("F")
    expect(backend.send(:osc_type_tag, nil)).to eq("N")
    expect(backend.send(:osc_type_tag, :lead)).to eq("S")
  end

  it "closes sockets that support close" do
    closable = Class.new do
      attr_reader :closed

      def initialize
        @closed = false
      end

      def close
        @closed = true
      end
    end.new
    backend = described_class.new(socket: closable)

    backend.close

    expect(closable.closed).to be(true)
  end
end
