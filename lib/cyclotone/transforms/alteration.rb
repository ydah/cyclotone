# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Alteration
      MAX_SEGMENTS = 4096

      def every(period, &block)
        every_with_offset(period, 0, &block)
      end

      def every_with_offset(period, offset, &block)
        normalized_period = validate_positive_rational(period, "every period")
        normalized_offset = Pattern.to_rational(offset)
        raise ArgumentError, "every requires a block" unless block

        Pattern.new do |span|
          if ((span.cycle_number - normalized_offset) % normalized_period).zero?
            block.call(self).query_span(span)
          else
            query_span(span)
          end
        end
      end

      def fold_every(periods, &block)
        Array(periods).reduce(self) do |pattern, period|
          pattern.every(period, &block)
        end
      end

      def sometimes(&block)
        sometimes_by(0.5, &block)
      end

      def sometimes_by(probability, &block)
        normalized_probability = validate_probability(probability, "sometimes probability")
        raise ArgumentError, "sometimes_by requires a block" unless block

        Pattern.new do |span|
          if Support::Deterministic.float(:sometimes, normalized_probability, span.cycle_number) < normalized_probability
            block.call(self).query_span(span)
          else
            query_span(span)
          end
        end
      end

      def rarely(&block)
        sometimes_by(0.25, &block)
      end

      def almost_always(&block)
        sometimes_by(0.9, &block)
      end

      def almost_never(&block)
        sometimes_by(0.1, &block)
      end

      def chunk(count, &block)
        normalized_count = validate_segment_count(count, "chunk count")
        raise ArgumentError, "chunk requires a block" unless block

        Pattern.new do |span|
          selected = span.cycle_number % normalized_count
          pieces = Array.new(normalized_count) do |index|
            segment = zoom(Rational(index, normalized_count), Rational(index + 1, normalized_count))
            index == selected ? block.call(segment) : segment
          end

          Pattern.fastcat(pieces).query_span(span)
        end
      end

      def scramble(count)
        normalized_count = validate_segment_count(count, "scramble count")

        reorder_segments(normalized_count) do |cycle|
          Array.new(normalized_count) { |index| index }.shuffle(random: Support::Deterministic.random(:scramble, cycle))
        end
      end

      def shuffle(count)
        scramble(count)
      end

      def iter(count)
        normalized_count = validate_segment_count(count, "iter count")

        reorder_segments(normalized_count) do |cycle|
          Array.new(normalized_count) { |index| (index + cycle) % normalized_count }
        end
      end

      def iter_back(count)
        normalized_count = validate_segment_count(count, "iter_back count")

        reorder_segments(normalized_count) do |cycle|
          Array.new(normalized_count) { |index| (index - cycle) % normalized_count }
        end
      end

      def degrade_by(probability)
        normalized_probability = validate_probability(probability, "degrade probability")

        select_events do |event|
          cycle = (event.onset || event.part.start).floor
          seed = [:degrade, normalized_probability, cycle, event.value, event.part.start]
          Support::Deterministic.float(seed) >= normalized_probability
        end
      end

      def degrade
        degrade_by(0.5)
      end

      def trunc(amount)
        limit = Pattern.to_rational(amount)
        raise ArgumentError, "trunc amount must be between 0 and 1" if limit.negative? || limit > 1

        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          allowed = TimeSpan.new(cycle_start, cycle_start + limit)
          overlap = span.intersection(allowed)
          next [] unless overlap

          query_span(overlap).map do |event|
            clipped_part = event.part.intersection(allowed)
            next unless clipped_part

            clipped_whole = event.whole&.intersection(allowed) || event.whole

            event.with_span(new_whole: clipped_whole, new_part: clipped_part)
          end.compact
        end
      end

      def linger(amount)
        zoom(0, amount)
      end

      def zoom(start_point, end_point)
        window_start = Pattern.to_rational(start_point)
        window_end = Pattern.to_rational(end_point)
        window_length = window_end - window_start
        raise ArgumentError, "zoom end must be greater than start" unless window_length.positive?

        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          source_span = TimeSpan.new(
            cycle_start + window_start + ((span.start - cycle_start) * window_length),
            cycle_start + window_start + ((span.stop - cycle_start) * window_length)
          )

          query_span(source_span).map do |event|
            Pattern.map_event(event) do |time|
              cycle_start + ((time - cycle_start - window_start) / window_length)
            end
          end
        end
      end

      def stripe(count)
        fast(count)
      end

      def slowstripe(count)
        slow(count)
      end

      def spread(function, values)
        normalized_values = validate_values(values, "spread values")
        raise ArgumentError, "spread requires a callable function" unless function.respond_to?(:call)

        sequence = Pattern.cat(normalized_values.map { |value| function.call(self, value) })
        Pattern.new { |span| sequence.query_span(span) }
      end

      def fastspread(function, values)
        normalized_values = validate_values(values, "fastspread values")
        raise ArgumentError, "fastspread requires a callable function" unless function.respond_to?(:call)

        Pattern.fastcat(normalized_values.map { |value| function.call(self, value) })
      end

      private

      def reorder_segments(count)
        normalized_count = validate_segment_count(count, "segment count")

        Pattern.new do |span|
          order = yield(span.cycle_number)
          segment_patterns = Array.new(normalized_count) do |index|
            zoom(Rational(order[index], normalized_count), Rational(order[index] + 1, normalized_count))
          end

          Pattern.fastcat(segment_patterns).query_span(span)
        end
      end

      def validate_positive_rational(value, label)
        normalized = Pattern.to_rational(value)
        raise ArgumentError, "#{label} must be positive" unless normalized.positive?

        normalized
      end

      def validate_probability(value, label)
        normalized = Float(value)
        raise ArgumentError, "#{label} must be finite" unless normalized.finite?
        raise ArgumentError, "#{label} must be between 0 and 1" unless normalized.between?(0.0, 1.0)

        normalized
      rescue ArgumentError, TypeError => error
        raise ArgumentError, "invalid #{label}: #{error.message}"
      end

      def validate_segment_count(value, label)
        normalized = Integer(value)
        raise ArgumentError, "#{label} must be positive" unless normalized.positive?
        raise ArgumentError, "#{label} must be <= #{MAX_SEGMENTS}" if normalized > MAX_SEGMENTS

        normalized
      rescue ArgumentError, TypeError => error
        raise ArgumentError, "invalid #{label}: #{error.message}"
      end

      def validate_values(values, label)
        normalized = Array(values)
        raise ArgumentError, "#{label} must not be empty" if normalized.empty?

        normalized
      end
    end
  end
end
