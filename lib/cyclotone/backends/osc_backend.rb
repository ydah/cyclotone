# frozen_string_literal: true

require "socket"

module Cyclotone
  module Backends
    class OSCBackend
      Double = Struct.new(:value, keyword_init: true)
      Blob = Struct.new(:bytes, keyword_init: true)

      attr_reader :host, :port, :address

      class << self
        def double(value)
          Double.new(value: value.to_f)
        end

        def blob(bytes)
          Blob.new(bytes: bytes.to_s.b)
        end
      end

      def initialize(
        host: "127.0.0.1",
        port: 57_120,
        address: "/dirt/play",
        socket: nil,
        socket_factory: nil,
        retries: 1
      )
        @host = host
        @port = port
        @address = address
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
        encode_message(address, payload_for(event, at: at, cps: cps))
      end

      def build_bundle(events, at:, cps: nil, timetag: at)
        messages = Array(events).map { |event| build_message(event, at: at, cps: cps) }
        encode_bundle(messages, timetag: timetag)
      end

      def send_event(event, at: Time.now.to_f, cps: nil, **_options)
        with_retry do
          @socket.send(build_message(event, at: at, cps: cps), 0, host, port)
        end
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      def flush
        self
      end

      def panic
        self
      end

      def close
        @socket.close if @socket.respond_to?(:close)
        self
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
        hash.sort_by { |key, _| Support::Deterministic.canonical_key(key) }.each_with_object([]) do |(key, value), payload|
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

        at.to_f + (event.duration.to_f / cps)
      end

      def encode_message(address, arguments)
        type_tags = arguments.map { |argument| osc_type_tag(argument) }.join

        padded(address) + padded(",#{type_tags}") + arguments.filter_map { |argument| encode_argument(argument) }.join
      end

      def osc_type_tag(argument)
        case argument
        when Double then "d"
        when Blob then "b"
        when Integer then "i"
        when Float then "f"
        when TrueClass then "T"
        when FalseClass then "F"
        when NilClass then "N"
        when Symbol then "S"
        else "s"
        end
      end

      def encode_argument(argument)
        case argument
        when Double
          [argument.value].pack("G")
        when Blob
          encode_blob(argument.bytes)
        when Integer
          [argument].pack("N")
        when Float
          [argument].pack("g")
        when TrueClass, FalseClass, NilClass
          nil
        else
          padded(argument.to_s)
        end
      end

      def encode_blob(bytes)
        data = bytes.to_s.b
        [data.bytesize].pack("N") + pad_bytes(data)
      end

      def encode_bundle(messages, timetag:)
        body = messages.map { |message| [message.bytesize].pack("N") + message }.join
        padded("#bundle") + encode_timetag(timetag) + body
      end

      def encode_timetag(value)
        return [0, 1].pack("NN") if value.nil? || value == :immediate

        seconds = value.to_f + 2_208_988_800
        whole = seconds.floor
        fraction = ((seconds - whole) * (2**32)).round
        [whole, fraction].pack("NN")
      end

      def padded(string)
        bytes = "#{string}\0".b
        pad_bytes(bytes)
      end

      def pad_bytes(bytes)
        padding = (4 - (bytes.bytesize % 4)) % 4
        bytes + ("\0".b * padding)
      end
    end
  end
end
