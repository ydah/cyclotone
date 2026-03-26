# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Alteration
      def every(period, &block)
        every_with_offset(period, 0, &block)
      end

      def every_with_offset(period, offset, &block)
        Pattern.new do |span|
          if ((span.cycle_number - offset) % period).zero?
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
        Pattern.new do |span|
          if Support::Deterministic.float(:sometimes, probability, span.cycle_number) < probability.to_f
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
        Pattern.new do |span|
          selected = span.cycle_number % count
          pieces = Array.new(count) do |index|
            segment = zoom(Rational(index, count), Rational(index + 1, count))
            index == selected ? block.call(segment) : segment
          end

          Pattern.fastcat(pieces).query_span(span)
        end
      end

      def scramble(count)
        reorder_segments(count) do |cycle|
          Array.new(count) { |index| index }.shuffle(random: Support::Deterministic.random(:scramble, cycle))
        end
      end

      def shuffle(count)
        scramble(count)
      end

      def iter(count)
        reorder_segments(count) do |cycle|
          Array.new(count) { |index| (index + cycle) % count }
        end
      end

      def iter_back(count)
        reorder_segments(count) do |cycle|
          Array.new(count) { |index| (index - cycle) % count }
        end
      end

      def degrade_by(probability)
        select_events do |event|
          cycle = (event.onset || event.part.start).floor
          seed = [:degrade, probability, cycle, event.value, event.part.start]
          Support::Deterministic.float(seed) >= probability.to_f
        end
      end

      def degrade
        degrade_by(0.5)
      end

      def trunc(amount)
        limit = Pattern.to_rational(amount)

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
        sequence = Pattern.cat(Array(values).map { |value| function.call(self, value) })
        Pattern.new { |span| sequence.query_span(span) }
      end

      def fastspread(function, values)
        Pattern.fastcat(Array(values).map { |value| function.call(self, value) })
      end

      private

      def reorder_segments(count)
        Pattern.new do |span|
          order = yield(span.cycle_number)
          segment_patterns = Array.new(count) do |index|
            zoom(Rational(order[index], count), Rational(order[index] + 1, count))
          end

          Pattern.fastcat(segment_patterns).query_span(span)
        end
      end
    end
  end
end
