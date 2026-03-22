# frozen_string_literal: true

module Cyclotone
  class Pattern
    attr_reader :query

    def initialize(&query_func)
      raise ArgumentError, "Pattern requires a query block" unless query_func

      @query = query_func
    end

    def query_span(span)
      span.cycle_spans.flat_map do |cycle_span|
        query.call(cycle_span)
      end.then { |events| self.class.sort_events(events) }
    end

    def query_cycle(cycle_number)
      query_span(TimeSpan.new(cycle_number, Rational(cycle_number) + 1))
    end

    def fmap(&transform)
      raise ArgumentError, "fmap requires a block" unless transform

      self.class.new do |span|
        query_span(span).map do |event|
          event.with_value(transform.call(event.value))
        end
      end
    end

    class << self
      def pure(value)
        new do |span|
          cycle_start = Rational(span.start.floor)
          whole = TimeSpan.new(cycle_start, cycle_start + 1)

          [Event.new(whole: whole, part: span, value: value)]
        end
      end

      alias atom pure

      def silence
        new { |_span| [] }
      end

      def fastcat(patterns)
        normalized_patterns = Array(patterns)
        raise ArgumentError, "fastcat requires at least one pattern" if normalized_patterns.empty?

        new do |span|
          cycle_start = Rational(span.start.floor)
          segment_length = Rational(1, normalized_patterns.length)

          normalized_patterns.each_with_index.flat_map do |pattern, index|
            segment_start = cycle_start + (segment_length * index)
            segment_stop = segment_start + segment_length
            segment_span = TimeSpan.new(segment_start, segment_stop)
            overlap = span.intersection(segment_span)

            next [] unless overlap

            local_span = TimeSpan.new(
              (overlap.start - segment_start) * normalized_patterns.length,
              (overlap.stop - segment_start) * normalized_patterns.length
            )

            pattern.query_span(local_span).map do |event|
              translate_event(event, scale: segment_length, offset: segment_start)
            end
          end.then { |events| sort_events(events) }
        end
      end

      def stack(patterns)
        normalized_patterns = Array(patterns)
        raise ArgumentError, "stack requires at least one pattern" if normalized_patterns.empty?

        new do |span|
          normalized_patterns.flat_map { |pattern| pattern.query_span(span) }.then do |events|
            sort_events(events)
          end
        end
      end

      def sort_events(events)
        events.sort_by do |event|
          [event.onset || event.part.start, event.offset || event.part.stop, event.value.to_s]
        end
      end

      private

      def translate_event(event, scale:, offset:)
        Event.new(
          whole: translate_span(event.whole, scale: scale, offset: offset),
          part: translate_span(event.part, scale: scale, offset: offset),
          value: event.value
        )
      end

      def translate_span(span, scale:, offset:)
        return nil unless span

        TimeSpan.new(
          offset + (span.start * scale),
          offset + (span.stop * scale)
        )
      end
    end
  end
end
