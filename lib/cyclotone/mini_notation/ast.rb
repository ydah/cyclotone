# frozen_string_literal: true

module Cyclotone
  module MiniNotation
    module AST
      class Node
        def self.deep_freeze(value)
          case value
          when Array
            value.map { |entry| deep_freeze(entry) }.freeze
          when Hash
            value.each_with_object({}) do |(key, entry), frozen_hash|
              frozen_hash[deep_freeze(key)] = deep_freeze(entry)
            end.freeze
          else
            value.freeze
          end
        end

        def ==(other)
          other.is_a?(self.class) && to_h == other.to_h
        end

        alias eql? ==

        def hash
          [self.class, to_h].hash
        end

        def to_mn
          AST.to_source(self)
        end
      end

      class Atom < Node
        attr_reader :value, :sample

        def initialize(value:, sample: nil)
          super()
          @value = value
          @sample = sample
          freeze
        end

        def with_sample(sample_number)
          self.class.new(value: value, sample: sample_number)
        end

        def to_h
          { value: value, sample: sample }
        end
      end

      class Rest < Node
        def to_h
          {}
        end
      end

      class Sequence < Node
        attr_reader :elements

        def initialize(elements:)
          super()
          @elements = Node.deep_freeze(elements)
          freeze
        end

        def to_h
          { elements: elements }
        end
      end

      class Stack < Node
        attr_reader :patterns

        def initialize(patterns:)
          super()
          @patterns = Node.deep_freeze(patterns)
          freeze
        end

        def to_h
          { patterns: patterns }
        end
      end

      class Alternating < Node
        attr_reader :patterns

        def initialize(patterns:)
          super()
          @patterns = Node.deep_freeze(patterns)
          freeze
        end

        def to_h
          { patterns: patterns }
        end
      end

      class Repeat < Node
        attr_reader :pattern, :count

        def initialize(pattern:, count:)
          super()
          @pattern = pattern
          @count = count.to_i
          freeze
        end

        def to_h
          { pattern: pattern, count: count }
        end
      end

      class Replicate < Node
        attr_reader :pattern, :count

        def initialize(pattern:, count:)
          super()
          @pattern = pattern
          @count = count.to_i
          freeze
        end

        def to_h
          { pattern: pattern, count: count }
        end
      end

      class Slow < Node
        attr_reader :pattern, :amount

        def initialize(pattern:, amount:)
          super()
          @pattern = pattern
          @amount = amount
          freeze
        end

        def to_h
          { pattern: pattern, amount: amount }
        end
      end

      class Elongate < Node
        attr_reader :pattern, :amount

        def initialize(pattern:, amount:)
          super()
          @pattern = pattern
          @amount = amount
          freeze
        end

        def increment(step = 1)
          self.class.new(pattern: pattern, amount: amount + step)
        end

        def to_h
          { pattern: pattern, amount: amount }
        end
      end

      class Degrade < Node
        attr_reader :pattern, :probability

        def initialize(pattern:, probability:)
          super()
          @pattern = pattern
          @probability = probability
          freeze
        end

        def to_h
          { pattern: pattern, probability: probability }
        end
      end

      class Choice < Node
        attr_reader :patterns

        def initialize(patterns:)
          super()
          @patterns = Node.deep_freeze(patterns)
          freeze
        end

        def to_h
          { patterns: patterns }
        end
      end

      class Euclidean < Node
        attr_reader :pattern, :pulses, :steps, :rotation

        def initialize(pattern:, pulses:, steps:, rotation: 0)
          super()
          @pattern = pattern
          @pulses = pulses.to_i
          @steps = steps.to_i
          @rotation = rotation.to_i
          freeze
        end

        def to_h
          { pattern: pattern, pulses: pulses, steps: steps, rotation: rotation }
        end
      end

      class Polymetric < Node
        attr_reader :patterns, :steps

        def initialize(patterns:, steps: nil)
          super()
          @patterns = Node.deep_freeze(patterns)
          @steps = steps&.to_i
          freeze
        end

        def to_h
          { patterns: patterns, steps: steps }
        end
      end

      module_function

      def to_source(node)
        case node
        when Atom
          node.sample ? "#{format_atom(node.value)}:#{node.sample}" : format_atom(node.value)
        when Rest
          "~"
        when Sequence
          node.elements.map { |element| to_source(element) }.join(" ")
        when Stack
          "[#{node.patterns.map { |pattern| to_source(pattern) }.join(", ")}]"
        when Alternating
          "<#{node.patterns.map { |pattern| to_source(pattern) }.join(" ")}>"
        when Repeat
          "#{group_if_needed(node.pattern)}*#{node.count}"
        when Replicate
          "#{group_if_needed(node.pattern)}!#{node.count}"
        when Slow
          "#{group_if_needed(node.pattern)}/#{node.amount}"
        when Elongate
          "#{group_if_needed(node.pattern)}@#{node.amount}"
        when Degrade
          "#{group_if_needed(node.pattern)}?#{node.probability}"
        when Choice
          node.patterns.map { |pattern| to_source(pattern) }.join(" | ")
        when Euclidean
          "#{group_if_needed(node.pattern)}(#{node.pulses},#{node.steps},#{node.rotation})"
        when Polymetric
          suffix = node.steps ? "%#{node.steps}" : ""
          "{#{node.patterns.map { |pattern| to_source(pattern) }.join(", ")}}#{suffix}"
        else
          raise ArgumentError, "unsupported AST node #{node.class}"
        end
      end

      def group_if_needed(node)
        node.is_a?(Atom) || node.is_a?(Rest) ? to_source(node) : "[#{to_source(node)}]"
      end
      private_class_method :group_if_needed

      def format_atom(value)
        return "#{value.numerator}/#{value.denominator}" if value.is_a?(Rational)

        text = value.to_s
        return text if text.match?(/\A[\w.-]+\z/)

        "\"#{text.gsub("\\", "\\\\\\").gsub("\"", "\\\"")}\""
      end
      private_class_method :format_atom
    end
  end
end
