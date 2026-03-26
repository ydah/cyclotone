# frozen_string_literal: true

require "socket"

module Cyclotone
  module Backends
    class OSCBackend
      attr_reader :host, :port

      def initialize(host: "127.0.0.1", port: 57_120, socket: nil, socket_factory: nil, retries: 1)
        @host = host
        @port = port
        @socket_factory = socket_factory || proc { UDPSocket.new }
        @retries = retries.to_i
        @socket = socket || build_socket
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      def payload_for(event, at:, cps: nil)
        values = event.value.is_a?(Hash) ? event.value : { value: event.value }

        [
          "when", at.to_f,
          "onset", absolute_onset(event, at),
          "offset", absolute_offset(event, at, cps)
        ].compact + flatten_hash(values)
      end

      def build_message(event, at:, cps: nil)
        encode_message("/dirt/play", payload_for(event, at: at, cps: cps))
      end

      def send_event(event, at: Time.now.to_f, cps: nil)
        with_retry do
          @socket.send(build_message(event, at: at, cps: cps), 0, host, port)
        end
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      private

      def with_retry
        attempts_remaining = @retries

        begin
          yield
        rescue StandardError
          raise if attempts_remaining <= 0

          attempts_remaining -= 1
          reconnect!
          retry
        end
      end

      def reconnect!
        @socket.close if @socket.respond_to?(:close)
        @socket = build_socket
      end

      def build_socket
        @socket_factory.call
      end

      def flatten_hash(hash)
        hash.each_with_object([]) do |(key, value), payload|
          payload << key.to_s
          payload << value
        end
      end

      def absolute_onset(event, at)
        return nil unless event.onset

        at.to_f
      end

      def absolute_offset(event, at, cps)
        return nil unless event.offset
        return event.offset.to_f if cps.nil? || event.duration.nil?

        at.to_f + (event.duration.to_f / cps.to_f)
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
