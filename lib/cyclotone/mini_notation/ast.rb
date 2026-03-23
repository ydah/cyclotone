# frozen_string_literal: true

module Cyclotone
  module MiniNotation
    module AST
      class Node
        def ==(other)
          other.is_a?(self.class) && to_h == other.to_h
        end

        alias eql? ==

        def hash
          [self.class, to_h].hash
        end
      end

      class Atom < Node
        attr_reader :value, :sample

        def initialize(value:, sample: nil)
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
          @elements = elements.freeze
          freeze
        end

        def to_h
          { elements: elements }
        end
      end

      class Stack < Node
        attr_reader :patterns

        def initialize(patterns:)
          @patterns = patterns.freeze
          freeze
        end

        def to_h
          { patterns: patterns }
        end
      end

      class Alternating < Node
        attr_reader :patterns

        def initialize(patterns:)
          @patterns = patterns.freeze
          freeze
        end

        def to_h
          { patterns: patterns }
        end
      end

      class Repeat < Node
        attr_reader :pattern, :count

        def initialize(pattern:, count:)
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
          @patterns = patterns.freeze
          freeze
        end

        def to_h
          { patterns: patterns }
        end
      end

      class Euclidean < Node
        attr_reader :pattern, :pulses, :steps, :rotation

        def initialize(pattern:, pulses:, steps:, rotation: 0)
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
          @patterns = patterns.freeze
          @steps = steps&.to_i
          freeze
        end

        def to_h
          { patterns: patterns, steps: steps }
        end
      end
    end
  end
end
