# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Accumulation
      def overlay(other)
        Pattern.stack([self, Pattern.ensure_pattern(other)])
      end

      def superimpose(&block)
        raise ArgumentError, "superimpose requires a block" unless block

        overlay(block.call(self))
      end

      def layer(functions)
        normalized_functions = Array(functions)
        raise ArgumentError, "layer requires functions" if normalized_functions.empty?

        Pattern.stack(normalized_functions.map { |function| function.call(self) })
      end

      def jux(&block)
        jux_by(1, &block)
      end

      def jux_by(amount, &block)
        raise ArgumentError, "jux_by requires a block" unless block

        offset = amount.to_f / 2.0
        left = merge(Controls.pan((0.5 - offset).clamp(0.0, 1.0)))
        right = block.call(self).merge(Controls.pan((0.5 + offset).clamp(0.0, 1.0)))
        Pattern.stack([left, right])
      end

      def weave(count, pattern, controls)
        functions = Array(controls).map do |control_pattern|
          proc { |base| base.merge(control_pattern) }
        end

        weave_with(count, pattern, functions)
      end

      def weave_with(count, pattern, functions)
        normalized_count = normalize_weave_count(count)
        normalized_functions = Array(functions)
        raise ArgumentError, "weave functions must not be empty" if normalized_functions.empty?

        Pattern.fastcat(
          Array.new(normalized_count) do |index|
            normalized_functions[index % normalized_functions.length].call(pattern)
          end
        )
      end

      private

      def normalize_weave_count(count)
        normalized_count = Integer(count)
        raise ArgumentError, "weave count must be positive" unless normalized_count.positive?

        normalized_count
      rescue ArgumentError, TypeError => error
        raise ArgumentError, "invalid weave count: #{error.message}"
      end
    end
  end
end
