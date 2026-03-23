# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Condition
      def when_mod(period, minimum, &block)
        Pattern.new do |span|
          (span.cycle_number % period) >= minimum ? block.call(self).query_span(span) : query_span(span)
        end
      end

      def fix(control_pattern, &block)
        transformed = block.call(self)

        Pattern.new do |span|
          query_span(span).map do |event|
            time = event.onset || event.part.start
            control_value = Pattern.ensure_pattern(control_pattern).query_point(time)
            next event unless truthy?(control_value)

            transformed_event = transformed.query_event_at(time)
            transformed_event ? transformed_event.with_span(new_whole: event.whole, new_part: event.part) : event
          end
        end
      end

      def unfix(control_pattern, &block)
        contrast(block, proc { |pattern| pattern }, control_pattern)
      end

      def contrast(true_function, false_function, control_pattern)
        true_pattern = true_function.call(self)
        false_pattern = false_function.call(self)

        Pattern.new do |span|
          query_span(span).map do |event|
            time = event.onset || event.part.start
            target_pattern = truthy?(Pattern.ensure_pattern(control_pattern).query_point(time)) ? true_pattern : false_pattern
            target_pattern.query_event_at(time)&.with_span(new_whole: event.whole, new_part: event.part) || event
          end
        end
      end

      def mask(bool_pattern)
        select_events do |event|
          truthy?(Pattern.ensure_pattern(bool_pattern).query_point(event.onset || event.part.start))
        end
      end

      def struct(bool_pattern)
        Pattern.ensure_pattern(bool_pattern).combine_left(self) do |gate, value|
          gate ? value : nil
        end.select_events { |event| !event.value.nil? }
      end

      private

      def truthy?(value)
        !(value.nil? || value == false || value == 0 || value == 0.0 || value == {})
      end
    end
  end
end
