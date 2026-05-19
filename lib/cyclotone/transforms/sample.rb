# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Sample
      def chop(count)
        normalized_count = validate_positive_integer(count, "chop count")

        Pattern.fastcat(
          Array.new(normalized_count) do |index|
            merge(Controls.begin(Rational(index, normalized_count))).merge(
              Controls.end(Rational(index + 1, normalized_count))
            )
          end
        )
      end

      def striate(count)
        chop(count)
      end

      def slice(count, pattern)
        normalized_count = validate_positive_integer(count, "slice count")
        selection = Pattern.ensure_pattern(pattern)

        map_events do |event|
          selected_value = selection.query_point(event.onset || event.part.start)
          next nil if selected_value.nil?

          index = selected_value.to_i % normalized_count
          merge_controls(event, begin: Rational(index, normalized_count), end: Rational(index + 1, normalized_count))
        end
      end

      def splice(count, pattern)
        slice(count, pattern).merge(Controls.speed(count))
      end

      def bite(count, pattern)
        slice(count, pattern).fast(count)
      end

      def chew(count, pattern)
        bite(count, pattern)
      end

      def randslice(count)
        normalized_count = validate_positive_integer(count, "randslice count")

        map_events do |event|
          index = Support::Deterministic.int(normalized_count, :randslice, event.value, event.part.start)
          merge_controls(event, begin: Rational(index, normalized_count), end: Rational(index + 1, normalized_count))
        end
      end

      def loop_at(cycles)
        normalized_cycles = Pattern.to_rational(cycles)
        raise ArgumentError, "loop_at cycles must be positive" unless normalized_cycles.positive?

        merge(Controls.speed(1.0 / normalized_cycles.to_f))
      end

      def segment(count)
        normalized_count = validate_positive_integer(count, "segment count")

        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          segment_length = Rational(1, normalized_count)

          Array.new(normalized_count) { |index| index }.filter_map do |index|
            segment_span = TimeSpan.new(
              cycle_start + (segment_length * index),
              cycle_start + (segment_length * (index + 1))
            )
            overlap = span.intersection(segment_span)
            next unless overlap

            value = query_point(segment_span.midpoint)
            Event.new(whole: segment_span, part: overlap, value: value)
          end
        end
      end

      private

      def merge_controls(event, values)
        merged_value = if event.value.is_a?(Hash)
                         event.value.merge(values)
                       else
                         values.merge(value: event.value)
                       end

        event.with_value(merged_value)
      end

      def validate_positive_integer(value, label)
        normalized = Integer(value)
        raise ArgumentError, "#{label} must be positive" unless normalized.positive?

        normalized
      rescue ArgumentError, TypeError => error
        raise ArgumentError, "invalid #{label}: #{error.message}"
      end
    end
  end
end
