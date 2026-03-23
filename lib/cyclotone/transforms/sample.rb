# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Sample
      def chop(count)
        Pattern.fastcat(
          Array.new(count) do |index|
            merge(Controls.begin(index.to_f / count)).merge(Controls.end((index + 1).to_f / count))
          end
        )
      end

      def striate(count)
        chop(count)
      end

      def slice(count, pattern)
        selection = Pattern.ensure_pattern(pattern)

        map_events do |event|
          index = selection.query_point(event.onset || event.part.start).to_i % count
          merge_controls(event, begin: index.to_f / count, end: (index + 1).to_f / count)
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
        map_events do |event|
          index = Support::Deterministic.int(count, :randslice, event.value, event.part.start)
          merge_controls(event, begin: index.to_f / count, end: (index + 1).to_f / count)
        end
      end

      def loop_at(cycles)
        merge(Controls.speed(1.0 / cycles.to_f))
      end

      def segment(count)
        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          segment_length = Rational(1, count)

          Array.new(count) { |index| index }.filter_map do |index|
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
    end
  end
end
