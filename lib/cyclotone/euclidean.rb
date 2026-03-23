# frozen_string_literal: true

module Cyclotone
  module Euclidean
    module_function

    def generate(pulses, steps, rotation = 0)
      normalized_pulses = pulses.to_i
      normalized_steps = steps.to_i

      raise ArgumentError, "steps must be positive" if normalized_steps <= 0
      raise ArgumentError, "pulses must be between 0 and steps" if normalized_pulses.negative? || normalized_pulses > normalized_steps

      pattern = bjorklund(normalized_pulses, normalized_steps)
      pattern = pattern.rotate(pattern.index(true) || 0)
      rotate(pattern, rotation)
    end

    def bjorklund(pulses, steps)
      return Array.new(steps, false) if pulses.zero?
      return Array.new(steps, true) if pulses == steps

      counts = []
      remainders = [pulses]
      divisor = steps - pulses
      level = 0

      while remainders[level] > 1
        counts << (divisor / remainders[level])
        remainders << (divisor % remainders[level])
        divisor = remainders[level]
        level += 1
      end

      counts << divisor

      pattern = []
      build(level, counts, remainders, pattern)
      pattern.take(steps)
    end
    private_class_method :bjorklund

    def build(level, counts, remainders, pattern)
      case level
      when -1
        pattern << false
      when -2
        pattern << true
      else
        counts[level].times { build(level - 1, counts, remainders, pattern) }
        build(level - 2, counts, remainders, pattern) unless remainders[level].zero?
      end
    end
    private_class_method :build

    def rotate(pattern, rotation)
      return pattern if pattern.empty?

      normalized_rotation = rotation.to_i % pattern.length

      pattern.rotate(normalized_rotation)
    end
    private_class_method :rotate
  end
end
