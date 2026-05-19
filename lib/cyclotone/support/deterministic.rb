# frozen_string_literal: true

require "digest"

module Cyclotone
  module Support
    module Deterministic
      module_function

      def seed_for(*parts)
        parts.flatten.compact.reduce(17) do |memo, part|
          ((memo * 31) ^ stable_hash(normalize(part))) & 0xFFFFFFFF
        end
      end

      def canonical_key(value)
        canonical_dump(normalize(value))
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

      private_class_method def self.stable_hash(value)
        Digest::SHA256.digest(canonical_dump(value)).unpack1("N")
      end

      private_class_method def self.canonical_dump(value)
        case value
        when NilClass
          "nil"
        when TrueClass, FalseClass
          "bool:#{value}"
        when Integer
          "int:#{value}"
        when Float
          "float:#{value.to_s}"
        when Symbol
          "sym:#{value}"
        when String
          "str:#{value.bytesize}:#{value}"
        when Array
          "arr:[#{value.map { |entry| canonical_dump(entry) }.join(",")}]"
        when Hash
          entries = value.sort_by { |key, _| canonical_dump(key) }.map do |key, entry|
            "#{canonical_dump(key)}=>#{canonical_dump(entry)}"
          end
          "hash:{#{entries.join(",")}}"
        else
          "#{value.class.name}:#{value.inspect}"
        end
      end
    end
  end
end
