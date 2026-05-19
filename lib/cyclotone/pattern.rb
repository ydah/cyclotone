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
    CACHE_LIMIT = 128
    CACHE_MUTEX = Mutex.new
    COMPILER_MUTEX = Mutex.new

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
      span = self.class.coerce_span(span)
      emitted_cycle_span = false
      events = []

      span.each_cycle_span do |cycle_span|
        emitted_cycle_span = true
        events.concat(query.call(cycle_span))
      end

      events.concat(query.call(span)) if !emitted_cycle_span && continuous?
      self.class.sort_events(events)
    end

    def query_cycle(cycle_number)
      query_span(TimeSpan.new(cycle_number, Rational(cycle_number) + 1))
    end

    def query_event_at(time)
      sample_time = self.class.to_rational(time)
      query_span(TimeSpan.new(sample_time, sample_time + self.class.sample_epsilon)).find do |event|
        event.covers_time?(sample_time)
      end
    end

    def query_point(time)
      query_event_at(time)&.value
    end

    def query_points(time)
      sample_time = self.class.to_rational(time)
      query_span(TimeSpan.new(sample_time, sample_time + self.class.sample_epsilon)).select do |event|
        event.covers_time?(sample_time)
      end.map(&:value)
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
        right_events_by_start = right_events.sort_by { |event| event.active_span.start }

        left_events.flat_map do |left_event|
          left_stop = left_event.active_span.stop

          right_events_by_start.filter_map do |right_event|
            break [] if right_event.active_span.start >= left_stop

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
      merge_right(other)
    end

    def merge_left(other)
      combine_left(other) do |left, right|
        merge_values(right, left)
      end
    end

    def merge_right(other)
      combine_left(other) do |left, right|
        merge_values(left, right)
      end
    end

    def merge_deep(other)
      combine_left(other) do |left, right|
        deep_merge_values(left, right)
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

      def atom_at(value, at:, duration: 0)
        onset_offset = to_rational(at)
        event_duration = to_rational(duration)
        raise ArgumentError, "atom duration must be non-negative" if event_duration.negative?

        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          onset = cycle_start + onset_offset
          whole = TimeSpan.new(onset, onset + event_duration)
          trigger_span = TimeSpan.new(onset, onset + sample_epsilon)
          part = span.intersection(trigger_span)

          part ? [Event.new(whole: whole, part: part, value: value)] : []
        end
      end

      def silence
        Pattern.new { |_span| [] }
      end

      def continuous(sample: :midpoint, &sampler)
        raise ArgumentError, "continuous requires a sampler block" unless sampler

        Pattern.new(continuous: true) do |span|
          [Event.new(whole: nil, part: span, value: sampler.call(sample_time(span, sample)))]
        end
      end

      def ensure_pattern(value)
        value.is_a?(Pattern) ? value : pure(value)
      end

      def to_rational(value)
        return value if value.is_a?(Rational)
        return Rational(value, 1) if value.is_a?(Integer)

        Rational(value.to_s)
      rescue ArgumentError, TypeError => error
        raise ArgumentError, "invalid rational value #{value.inspect}: #{error.message}"
      end

      def timecat(weighted_patterns)
        normalized = Array(weighted_patterns).map do |weight, pattern|
          normalized_weight = to_rational(weight)
          raise ArgumentError, "timecat weights must be positive" unless normalized_weight.positive?

          [normalized_weight, pattern]
        end
        raise ArgumentError, "timecat requires patterns" if normalized.empty?

        total_weight = normalized.sum { |weight, _pattern| weight }
        raise ArgumentError, "timecat total weight must be positive" unless total_weight.positive?

        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          cursor = cycle_start

          normalized.flat_map do |weight, pattern|
            segment_length = weight / total_weight
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

      def randcat(patterns, namespace: :randcat)
        normalized = Array(patterns)
        raise ArgumentError, "randcat requires patterns" if normalized.empty?

        Pattern.new do |span|
          index = Support::Deterministic.int(normalized.length, namespace, span.cycle_number)
          ensure_pattern(normalized[index]).query_span(span)
        end
      end

      def append(first, second)
        cat([first, second])
      end

      def fast_append(first, second)
        fastcat([first, second])
      end

      def stack(patterns, empty: :error)
        normalized_patterns = Array(patterns).map { |pattern| ensure_pattern(pattern) }
        if normalized_patterns.empty?
          return silence if empty == :silence

          raise ArgumentError, "stack requires at least one pattern"
        end

        Pattern.new do |span|
          normalized_patterns.flat_map { |pattern| pattern.query_span(span) }.then do |events|
            sort_events(events)
          end
        end
      end

      def stack_or_silence(patterns)
        stack(patterns, empty: :silence)
      end

      def overlay(first, second)
        stack([first, second])
      end

      def mn(string)
        source = string.to_s
        cached_pattern(source) { compiler.compile(parser.parse(source)) }
      end

      def mn!(string)
        mn(string)
      end

      def try_mn(string)
        mn(string)
      rescue ParseError, ArgumentError
        nil
      end

      def parser
        MiniNotation::Parser.new
      end

      def compiler
        return @compiler if @compiler

        COMPILER_MUTEX.synchronize do
          @compiler ||= MiniNotation::Compiler.new
        end
      end

      def sort_events(events)
        events.sort_by do |event|
          [
            event.onset || event.part.start,
            event.offset || event.part.stop,
            Support::Deterministic.canonical_key(event.value)
          ]
        end
      end

      def coerce_span(value)
        return value if value.is_a?(TimeSpan)
        return TimeSpan.new(value.fetch(0), value.fetch(1)) if value.respond_to?(:fetch)

        raise ArgumentError, "expected TimeSpan or [start, stop], got #{value.class}"
      end

      def sample_epsilon
        @sample_epsilon ||= SAMPLE_EPSILON
      end

      def sample_epsilon=(value)
        normalized = to_rational(value)
        raise ArgumentError, "sample epsilon must be positive" unless normalized.positive?

        @sample_epsilon = normalized
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

      private

      def sample_time(span, sample)
        case sample
        when :begin, :start
          span.start
        when :end, :stop
          span.stop
        when :midpoint, :center
          span.midpoint
        else
          raise ArgumentError, "unknown continuous sample point #{sample.inspect}"
        end
      end

      def cached_pattern(source)
        CACHE_MUTEX.synchronize do
          @mn_cache ||= {}
          @mn_cache_order ||= []

          return @mn_cache[source] if @mn_cache.key?(source)

          pattern = yield
          @mn_cache[source] = pattern
          @mn_cache_order << source

          @mn_cache.delete(@mn_cache_order.shift) while @mn_cache_order.length > CACHE_LIMIT

          pattern
        end
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
      return left if right.nil?

      if left.is_a?(Hash) && right.is_a?(Hash)
        keys = left.keys | right.keys
        keys.to_h do |key|
          value =
            if left.key?(key) && right.key?(key) && right[key].nil?
              left[key]
            elsif left.key?(key) && right.key?(key) && left[key].respond_to?(operator)
              left[key].public_send(operator, right[key])
            else
              right.fetch(key, left[key])
            end

          [key, value]
        end
      elsif left.respond_to?(operator)
        left.public_send(operator, right)
      else
        left
      end
    end

    def merge_values(left, right)
      if left.is_a?(Hash) && right.is_a?(Hash)
        left.merge(right.compact)
      elsif right.nil?
        left
      else
        right
      end
    end

    def deep_merge_values(left, right)
      return left if right.nil?
      return right unless left.is_a?(Hash) && right.is_a?(Hash)

      right.each_with_object(left.dup) do |(key, value), merged|
        next if value.nil?

        merged[key] = if merged[key].is_a?(Hash) && value.is_a?(Hash)
                        deep_merge_values(merged[key], value)
                      else
                        value
                      end
      end
    end
  end
end
