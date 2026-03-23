# frozen_string_literal: true

require "socket"

module Cyclotone
  module Backends
    class OSCBackend
      attr_reader :host, :port

      def initialize(host: "127.0.0.1", port: 57_120, socket: nil)
        @host = host
        @port = port
        @socket = socket || UDPSocket.new
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      def payload_for(event, at:)
        values = event.value.is_a?(Hash) ? event.value : { value: event.value }

        [
          "when", at.to_f,
          "onset", event.onset&.to_f,
          "offset", event.offset&.to_f
        ].compact + flatten_hash(values)
      end

      def build_message(event, at:)
        encode_message("/dirt/play", payload_for(event, at: at))
      end

      def send_event(event, at: Time.now.to_f)
        @socket.send(build_message(event, at: at), 0, host, port)
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      private

      def flatten_hash(hash)
        hash.each_with_object([]) do |(key, value), payload|
          payload << key.to_s
          payload << value
        end
      end

      def encode_message(address, arguments)
        type_tags = arguments.map do |argument|
          case argument
          when Integer then "i"
          when Float then "f"
          else "s"
          end
        end.join

        padded(address) + padded(",#{type_tags}") + arguments.map { |argument| encode_argument(argument) }.join
      end

      def encode_argument(argument)
        case argument
        when Integer
          [argument].pack("N")
        when Float
          [argument].pack("g")
        else
          padded(argument.to_s)
        end
      end

      def padded(string)
        bytes = "#{string}\0"
        padding = (4 - (bytes.bytesize % 4)) % 4
        bytes + ("\0" * padding)
      end
    end
  end
end
