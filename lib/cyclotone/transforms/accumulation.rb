# frozen_string_literal: true

module Cyclotone
  module Transforms
    module Accumulation
      def overlay(other)
        Pattern.stack([self, Pattern.ensure_pattern(other)])
      end

      def superimpose(&block)
        overlay(block.call(self))
      end

      def layer(functions)
        Pattern.stack(functions.map { |function| function.call(self) })
      end

      def jux(&block)
        jux_by(1, &block)
      end

      def jux_by(amount, &block)
        left = merge(Controls.pan(0.5 - (amount.to_f / 2.0)))
        right = block.call(self).merge(Controls.pan(0.5 + (amount.to_f / 2.0)))
        Pattern.stack([left, right])
      end

      def weave(count, pattern, controls)
        functions = Array(controls).map do |control_pattern|
          proc { |base| base.merge(control_pattern) }
        end

        weave_with(count, pattern, functions)
      end

      def weave_with(count, pattern, functions)
        Pattern.fastcat(
          Array.new(count) do |index|
            functions[index % functions.length].call(pattern)
          end
        )
      end
    end
  end
end
