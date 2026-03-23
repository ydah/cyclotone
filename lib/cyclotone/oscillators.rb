# frozen_string_literal: true

module Cyclotone
  module Oscillators
    module_function

    def sine
      Pattern.continuous { |time| (Math.sin(phase(time)) + 1.0) / 2.0 }
    end

    def cosine
      Pattern.continuous { |time| (Math.cos(phase(time)) + 1.0) / 2.0 }
    end

    def tri
      Pattern.continuous do |time|
        position = cycle_position(time)
        position < 0.5 ? position * 2.0 : (1.0 - position) * 2.0
      end
    end

    def saw
      Pattern.continuous { |time| cycle_position(time) }
    end

    def isaw
      Pattern.continuous { |time| 1.0 - cycle_position(time) }
    end

    def square
      Pattern.continuous { |time| cycle_position(time) < 0.5 ? 0.0 : 1.0 }
    end

    def rand
      Pattern.continuous do |time|
        cycle = time.floor
        step = ((cycle_position(time) * 128).floor).to_i
        Support::Deterministic.float(:rand, cycle, step)
      end
    end

    def irand(maximum)
      rand.fmap { |value| (value * maximum.to_i).floor }
    end

    def perlin
      Pattern.continuous do |time|
        left = time.floor
        right = left + 1
        amount = cycle_position(time)
        smooth = amount * amount * (3.0 - (2.0 * amount))
        left_value = Support::Deterministic.float(:perlin, left)
        right_value = Support::Deterministic.float(:perlin, right)

        left_value + ((right_value - left_value) * smooth)
      end
    end

    def range(low, high, pattern)
      Pattern.ensure_pattern(pattern).fmap do |value|
        low.to_f + ((high.to_f - low.to_f) * value.to_f)
      end
    end

    def smooth(pattern)
      source = Pattern.ensure_pattern(pattern)

      Pattern.continuous do |time|
        current = source.query_point(time)
        next current unless current.nil?

        source.query_point(time - Pattern::SAMPLE_EPSILON)
      end
    end

    def cycle_position(time)
      time.to_f - time.floor
    end
    private_class_method :cycle_position

    def phase(time)
      cycle_position(time) * Math::PI * 2.0
    end
    private_class_method :phase
  end
end
