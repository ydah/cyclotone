# frozen_string_literal: true

module Cyclotone
  class Pattern
    include Transforms::Time
    include Transforms::Concatenation
    include Transforms::Accumulation
    include Transforms::Alteration
    include Transforms::Condition
    include Transforms::Sample

    SAMPLE_EPSILON = Rational(1, 1024)

    attr_reader :query

    def initialize(continuous: false, &query_func)
      raise ArgumentError, "Pattern requires a query block" unless query_func

      @continuous = continuous
      @query = query_func
      freeze
    end

    def continuous?
      @continuous
    end

    def query_span(span)
      cycle_spans = span.cycle_spans
      cycle_spans = [span] if cycle_spans.empty? && continuous?

      cycle_spans.flat_map { |cycle_span| query.call(cycle_span) }.then do |events|
        self.class.sort_events(events)
      end
    end

    def query_cycle(cycle_number)
      query_span(TimeSpan.new(cycle_number, Rational(cycle_number) + 1))
    end

    def query_event_at(time)
      query_span(TimeSpan.new(time, time + SAMPLE_EPSILON)).find { |event| event.covers_time?(time) }
    end

    def query_point(time)
      query_event_at(time)&.value
    end

    def fmap(&transform)
      raise ArgumentError, "fmap requires a block" unless transform

      Pattern.new(continuous: continuous?) do |span|
        query_span(span).map { |event| event.with_value(transform.call(event.value)) }
      end
    end

    def map_events(&transform)
      Pattern.new(continuous: continuous?) do |span|
        query_span(span).map { |event| transform.call(event) }.compact
      end
    end

    def flat_map_events(&transform)
      Pattern.new(continuous: continuous?) do |span|
        query_span(span).flat_map { |event| Array(transform.call(event)) }.compact
      end
    end

    def select_events(&predicate)
      Pattern.new(continuous: continuous?) do |span|
        query_span(span).select { |event| predicate.call(event) }
      end
    end

    def combine_left(other, &operation)
      other_pattern = self.class.ensure_pattern(other)

      Pattern.new(continuous: continuous?) do |span|
        query_span(span).map do |event|
          time = event.onset || event.part.start
          other_value = other_pattern.query_point(time)
          event.with_value(operation.call(event.value, other_value))
        end
      end
    end

    def combine_right(other, &operation)
      self.class.ensure_pattern(other).combine_left(self) do |right_value, left_value|
        operation.call(left_value, right_value)
      end
    end

    def combine_both(other, &operation)
      other_pattern = self.class.ensure_pattern(other)

      Pattern.new do |span|
        left_events = query_span(span)
        right_events = other_pattern.query_span(span)

        left_events.flat_map do |left_event|
          right_events.filter_map do |right_event|
            overlap = left_event.active_span.intersection(right_event.active_span)
            next unless overlap

            part = overlap.intersection(span)
            next unless part

            whole = left_event.whole && right_event.whole ? left_event.whole.intersection(right_event.whole) : nil

            Event.new(
              whole: whole,
              part: part,
              value: operation.call(left_event.value, right_event.value)
            )
          end
        end
      end
    end

    def add(other, structure: :both)
      apply_binary_operation(other, structure: structure) { |left, right| combine_scalar(left, right, :+) }
    end

    def sub(other, structure: :both)
      apply_binary_operation(other, structure: structure) { |left, right| combine_scalar(left, right, :-) }
    end

    def mul(other, structure: :both)
      apply_binary_operation(other, structure: structure) { |left, right| combine_scalar(left, right, :*) }
    end

    def div(other, structure: :both)
      apply_binary_operation(other, structure: structure) { |left, right| combine_scalar(left, right, :/) }
    end

    def mod(other, structure: :both)
      apply_binary_operation(other, structure: structure) { |left, right| combine_scalar(left, right, :%) }
    end

    def merge(other)
      combine_left(other) do |left, right|
        if left.is_a?(Hash) && right.is_a?(Hash)
          left.merge(right)
        elsif right.nil?
          left
        else
          right
        end
      end
    end

    def +(other)
      add(other)
    end

    def -(other)
      sub(other)
    end

    def *(other)
      mul(other)
    end

    def /(other)
      div(other)
    end

    def %(other)
      mod(other)
    end

    class << self
      def pure(value)
        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          whole = TimeSpan.new(cycle_start, cycle_start + 1)
          [Event.new(whole: whole, part: span, value: value)]
        end
      end

      alias atom pure

      def silence
        Pattern.new { |_span| [] }
      end

      def continuous(&sampler)
        Pattern.new(continuous: true) do |span|
          [Event.new(whole: nil, part: span, value: sampler.call(span.midpoint))]
        end
      end

      def ensure_pattern(value)
        value.is_a?(Pattern) ? value : pure(value)
      end

      def to_rational(value)
        return value if value.is_a?(Rational)
        return Rational(value, 1) if value.is_a?(Integer)

        Rational(value.to_s)
      end

      def timecat(weighted_patterns)
        normalized = Array(weighted_patterns)
        raise ArgumentError, "timecat requires patterns" if normalized.empty?

        total_weight = normalized.sum { |weight, _pattern| to_rational(weight) }

        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          cursor = cycle_start

          normalized.flat_map do |weight, pattern|
            normalized_weight = to_rational(weight)
            segment_length = normalized_weight / total_weight
            segment_span = TimeSpan.new(cursor, cursor + segment_length)
            overlap = span.intersection(segment_span)
            cursor += segment_length

            next [] unless overlap

            local_span = TimeSpan.new(
              (overlap.start - segment_span.start) / segment_length,
              (overlap.stop - segment_span.start) / segment_length
            )

            ensure_pattern(pattern).query_span(local_span).map do |event|
              map_event(event) do |time|
                segment_span.start + (time * segment_length)
              end
            end
          end
        end
      end

      def fastcat(patterns)
        timecat(Array(patterns).map { |pattern| [1, pattern] })
      end

      def cat(patterns)
        normalized = Array(patterns)
        raise ArgumentError, "cat requires patterns" if normalized.empty?

        Pattern.new do |span|
          cycle = span.cycle_number
          index = cycle % normalized.length
          local_cycle = cycle / normalized.length
          cycle_offset = cycle - local_cycle
          local_span = span.shift(-cycle_offset)

          ensure_pattern(normalized[index]).query_span(local_span).map do |event|
            shift_event(event, cycle_offset)
          end
        end
      end

      def randcat(patterns)
        normalized = Array(patterns)

        Pattern.new do |span|
          index = Support::Deterministic.int(normalized.length, :randcat, span.cycle_number)
          ensure_pattern(normalized[index]).query_span(span)
        end
      end

      def append(first, second)
        cat([first, second])
      end

      def fast_append(first, second)
        fastcat([first, second])
      end

      def stack(patterns)
        normalized_patterns = Array(patterns).map { |pattern| ensure_pattern(pattern) }
        raise ArgumentError, "stack requires at least one pattern" if normalized_patterns.empty?

        Pattern.new do |span|
          normalized_patterns.flat_map { |pattern| pattern.query_span(span) }.then do |events|
            sort_events(events)
          end
        end
      end

      def overlay(first, second)
        stack([first, second])
      end

      def mn(string)
        compiler.compile(parser.parse(string))
      end

      def parser
        @parser ||= MiniNotation::Parser.new
      end

      def compiler
        @compiler ||= MiniNotation::Compiler.new
      end

      def sort_events(events)
        events.sort_by do |event|
          [event.onset || event.part.start, event.offset || event.part.stop, event.value.to_s]
        end
      end

      def map_span(span, &block)
        return nil unless span

        TimeSpan.new(block.call(span.start), block.call(span.stop))
      end

      def map_event(event, &block)
        Event.new(
          whole: map_span(event.whole, &block),
          part: map_span(event.part, &block),
          value: event.value
        )
      end

      def shift_event(event, amount)
        offset = to_rational(amount)
        map_event(event) { |time| time + offset }
      end
    end

    private

    def apply_binary_operation(other, structure:, &operation)
      case structure
      when :left
        combine_left(other, &operation)
      when :right
        combine_right(other, &operation)
      else
        combine_both(other, &operation)
      end
    end

    def combine_scalar(left, right, operator)
      if left.is_a?(Hash) && right.is_a?(Hash)
        keys = left.keys | right.keys
        keys.each_with_object({}) do |key, result|
          result[key] =
            if left.key?(key) && right.key?(key) && left[key].respond_to?(operator)
              left[key].public_send(operator, right[key])
            else
              right.fetch(key, left[key])
            end
        end
      elsif right.nil?
        left
      elsif left.respond_to?(operator)
        left.public_send(operator, right)
      else
        left
      end
    end
  end
end
