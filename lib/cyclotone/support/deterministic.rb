# frozen_string_literal: true

module Cyclotone
  module Support
    module Deterministic
      module_function

      def seed_for(*parts)
        parts.flatten.compact.reduce(17) do |memo, part|
          ((memo * 31) ^ normalize(part).hash) & 0xFFFFFFFF
        end
      end

      def random(*parts)
        Random.new(seed_for(*parts))
      end

      def float(*parts)
        random(*parts).rand
      end

      def int(max, *parts)
        return 0 if max.to_i <= 0

        random(*parts).rand(max.to_i)
      end

      private_class_method def self.normalize(value)
        case value
        when Rational
          [value.numerator, value.denominator]
        when Array
          value.map { |entry| normalize(entry) }
        when Hash
          value.sort_by { |key, _| key.to_s }.map { |key, item| [key, normalize(item)] }
        else
          value
        end
      end
    end
  end
end
