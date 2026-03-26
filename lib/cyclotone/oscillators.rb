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
      return source if source.continuous?

      Pattern.continuous do |time|
        interpolate(source, Pattern.to_rational(time))
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

    def interpolate(source, time)
      anchors = anchors_for(source, time)
      return source.query_point(time) if anchors.empty?

      left = anchors.reverse.find { |anchor| anchor[:time] <= time } || anchors.first
      right = anchors.find { |anchor| anchor[:time] >= time } || anchors.last
      return left[:value] if left[:time] == right[:time]

      amount = (time - left[:time]).to_f / (right[:time] - left[:time]).to_f
      interpolate_value(left[:value], right[:value], amount)
    end
    private_class_method :interpolate

    def anchors_for(source, time)
      window = TimeSpan.new(time.floor - 1, time.floor + 2)

      source.query_span(window).each_with_object([]) do |event, anchors|
        next if event.part.duration.zero?

        anchors << { time: event.part.midpoint, value: event.value }
      end.sort_by { |anchor| anchor[:time] }
    end
    private_class_method :anchors_for

    def interpolate_value(left, right, amount)
      if left.is_a?(Numeric) && right.is_a?(Numeric)
        left.to_f + ((right.to_f - left.to_f) * amount)
      elsif left.is_a?(Hash) && right.is_a?(Hash)
        interpolate_hash(left, right, amount)
      else
        amount >= 0.5 ? right : left
      end
    end
    private_class_method :interpolate_value

    def interpolate_hash(left, right, amount)
      (left.keys | right.keys).each_with_object({}) do |key, result|
        result[key] =
          if left.key?(key) && right.key?(key)
            interpolate_value(left[key], right[key], amount)
          else
            amount >= 0.5 ? right.fetch(key, left[key]) : left.fetch(key, right[key])
          end
      end
    end
    private_class_method :interpolate_hash
  end
end
