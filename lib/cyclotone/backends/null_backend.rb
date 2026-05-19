# frozen_string_literal: true

module Cyclotone
  module Backends
    class NullBackend
      attr_reader :events

      def initialize
        @events = []
      end

      def send_event(event, at:, **options)
        @events << { event: event, at: at, options: options }
        self
      end

      def flush
        @events.clear
        self
      end

      def close
        self
      end

      def panic
        self
      end
    end

    DryRunBackend = NullBackend
  end
end
