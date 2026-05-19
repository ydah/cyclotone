# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Time
      def fast(amount)
        factor = Pattern.to_rational(amount)
        raise ArgumentError, "fast amount must be positive" unless factor.positive?

        Pattern.new do |span|
          source_span = TimeSpan.new(span.start * factor, span.stop * factor)

          query_span(source_span).map do |event|
            Pattern.map_event(event) { |time| time / factor }
          end
        end
      end

      def slow(amount)
        factor = Pattern.to_rational(amount)
        raise ArgumentError, "slow amount must be positive" unless factor.positive?

        fast(Rational(1, 1) / factor)
      end

      def early(amount)
        offset = Pattern.to_rational(amount)

        Pattern.new do |span|
          query_span(span.shift(offset)).map do |event|
            Pattern.shift_event(event, -offset)
          end
        end
      end

      def late(amount)
        early(-Pattern.to_rational(amount))
      end

      def rev
        Pattern.new do |span|
          cycle_start = Rational(span.cycle_number)
          reversed_span = span.reverse_within(cycle_start)

          query_span(reversed_span).map do |event|
            event.with_span(
              new_whole: event.whole&.reverse_within(cycle_start),
              new_part: event.part.reverse_within(cycle_start)
            )
          end
        end
      end

      def palindrome
        Pattern.new do |span|
          span.cycle_number.even? ? rev.query_span(span) : query_span(span)
        end
      end

      def hurry(amount)
        fast(amount).fmap do |value|
          next value unless value.is_a?(Hash)

          current_speed = value[:speed] || 1.0
          value.merge(speed: current_speed * amount.to_f)
        end
      end

      def off(amount, &block)
        raise ArgumentError, "off requires a block" unless block

        transformed = block.call(self).early(amount)
        Pattern.stack([self, transformed])
      end

      def swing(amount, div = 4)
        normalized_div = Pattern.to_rational(div)
        raise ArgumentError, "swing division must be positive" unless normalized_div.positive?

        step_shift = Pattern.to_rational(amount) / normalized_div

        map_events do |event|
          next event unless event.onset

          cycle_start = Rational(event.onset.floor)
          step_index = ((event.onset - cycle_start) * div).floor.to_i
          next event if step_index.even?

          shifted = Pattern.shift_event(event, step_shift)
          cycle_span = TimeSpan.new(cycle_start, cycle_start + 1)
          clipped_part = shifted.part.intersection(cycle_span)
          next nil unless clipped_part

          clipped_whole = shifted.whole&.intersection(cycle_span) || shifted.whole
          shifted.with_span(part: clipped_part, whole: clipped_whole)
        end
      end

      def inside(amount, &block)
        raise ArgumentError, "inside requires a block" unless block

        slow(amount).then(&block).fast(amount)
      end

      def outside(amount, &block)
        raise ArgumentError, "outside requires a block" unless block

        fast(amount).then(&block).slow(amount)
      end
    end
  end
end
