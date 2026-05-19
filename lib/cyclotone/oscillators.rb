# frozen_string_literal: true

module Cyclotone
  module Oscillators
    module_function

    def sine(freq: 1, phase: 0, bipolar: false)
      oscillator(freq: freq, phase_offset: phase, bipolar: bipolar) do |time|
        (Math.sin(phase(time)) + 1.0) / 2.0
      end
    end

    def cosine(freq: 1, phase: 0, bipolar: false)
      oscillator(freq: freq, phase_offset: phase, bipolar: bipolar) do |time|
        (Math.cos(phase(time)) + 1.0) / 2.0
      end
    end

    def tri(freq: 1, phase: 0, bipolar: false)
      oscillator(freq: freq, phase_offset: phase, bipolar: bipolar) do |time|
        position = cycle_position(time)
        position < 0.5 ? position * 2.0 : (1.0 - position) * 2.0
      end
    end

    def saw(freq: 1, phase: 0, bipolar: false)
      oscillator(freq: freq, phase_offset: phase, bipolar: bipolar) { |time| cycle_position(time) }
    end

    def isaw(freq: 1, phase: 0, bipolar: false)
      oscillator(freq: freq, phase_offset: phase, bipolar: bipolar) { |time| 1.0 - cycle_position(time) }
    end

    def square(freq: 1, phase: 0, bipolar: false)
      oscillator(freq: freq, phase_offset: phase, bipolar: bipolar) { |time| cycle_position(time) < 0.5 ? 0.0 : 1.0 }
    end

    def rand(steps: 128)
      normalized_steps = positive_integer(steps, "rand steps")

      Pattern.continuous do |time|
        cycle = time.floor
        step = (cycle_position(time) * normalized_steps).floor.to_i
        Support::Deterministic.float(:rand, cycle, step)
      end
    end

    def irand(maximum)
      normalized_maximum = positive_integer(maximum, "irand maximum")

      rand.fmap { |value| (value * normalized_maximum).floor }
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

    def range(low, high, pattern, mode: :raw)
      Pattern.ensure_pattern(pattern).fmap do |value|
        normalized_value = normalize_range_value(value.to_f, mode)
        low.to_f + ((high.to_f - low.to_f) * normalized_value)
      end
    end

    def bipolar(pattern)
      Pattern.ensure_pattern(pattern).fmap { |value| (value.to_f * 2.0) - 1.0 }
    end

    def noise(steps: 128)
      rand(steps: steps)
    end

    def sample_and_hold(pattern, steps: 8)
      normalized_steps = positive_integer(steps, "sample_and_hold steps")
      source = Pattern.ensure_pattern(pattern)

      Pattern.continuous do |time|
        sampled_time = Rational((time * normalized_steps).floor, normalized_steps)
        source.query_point(sampled_time)
      end
    end

    def brownian(step: 0.1)
      normalized_step = step.to_f
      raise ArgumentError, "brownian step must be positive" unless normalized_step.positive?

      Pattern.continuous do |time|
        cycle = time.floor
        steps = (0..cycle).reduce(0.5) do |value, index|
          delta = (Support::Deterministic.float(:brownian, index) * 2.0) - 1.0
          (value + (delta * normalized_step)).clamp(0.0, 1.0)
        end
        steps
      end
    end

    def smooth(pattern, interpolator: nil, &block)
      source = Pattern.ensure_pattern(pattern)
      return source if source.continuous?

      interpolation = block || interpolator
      cache = {}
      Pattern.continuous do |time|
        rational_time = Pattern.to_rational(time)
        cache.fetch(rational_time) do
          cache[rational_time] = interpolate(source, rational_time, interpolation)
          cache.shift if cache.length > 256
          cache[rational_time]
        end
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

    def oscillator(freq:, phase_offset:, bipolar:)
      normalized_freq = Pattern.to_rational(freq)
      raise ArgumentError, "oscillator frequency must be positive" unless normalized_freq.positive?

      offset = Pattern.to_rational(phase_offset)
      Pattern.continuous do |time|
        value = yield((time * normalized_freq) + offset)
        bipolar ? (value * 2.0) - 1.0 : value
      end
    end
    private_class_method :oscillator

    def normalize_range_value(value, mode)
      case mode.to_sym
      when :raw
        value
      when :clamp
        value.clamp(0.0, 1.0)
      when :wrap
        value % 1.0
      when :fold
        folded = value % 2.0
        folded > 1.0 ? 2.0 - folded : folded
      else
        raise ArgumentError, "unknown range mode #{mode}"
      end
    end
    private_class_method :normalize_range_value

    def positive_integer(value, label)
      normalized = Integer(value)
      raise ArgumentError, "#{label} must be positive" unless normalized.positive?

      normalized
    rescue ArgumentError, TypeError => error
      raise ArgumentError, "invalid #{label}: #{error.message}"
    end

    def interpolate(source, time, interpolation)
      anchors = anchors_for(source, time)
      return source.query_point(time) if anchors.empty?

      left = anchors.reverse.find { |anchor| anchor[:time] <= time } || anchors.first
      right = anchors.find { |anchor| anchor[:time] >= time } || anchors.last
      return left[:value] if left[:time] == right[:time]

      amount = (time - left[:time]).to_f / (right[:time] - left[:time])
      interpolate_value(left[:value], right[:value], amount, interpolation)
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

    def interpolate_value(left, right, amount, interpolation = nil)
      if left.is_a?(Numeric) && right.is_a?(Numeric)
        left.to_f + ((right.to_f - left.to_f) * amount)
      elsif left.is_a?(Hash) && right.is_a?(Hash)
        interpolate_hash(left, right, amount, interpolation)
      elsif interpolation
        interpolation.call(left, right, amount)
      else
        amount >= 0.5 ? right : left
      end
    end
    private_class_method :interpolate_value

    def interpolate_hash(left, right, amount, interpolation)
      (left.keys | right.keys).to_h do |key|
        value =
          if left.key?(key) && right.key?(key)
            interpolate_value(left[key], right[key], amount, interpolation)
          else
            amount >= 0.5 ? right.fetch(key, left[key]) : left.fetch(key, right[key])
          end

        [key, value]
      end
    end
    private_class_method :interpolate_hash
  end
end
