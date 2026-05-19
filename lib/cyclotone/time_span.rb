# frozen_string_literal: true

module Cyclotone
  class TimeSpan
    attr_reader :start, :stop

    def initialize(start_time, stop_time)
      @start = coerce_time(start_time)
      @stop = coerce_time(stop_time)

      raise ArgumentError, "stop time must be greater than or equal to start time" if @stop < @start

      freeze
    end

    def duration
      stop - start
    end

    def midpoint
      (start + stop) / 2
    end

    def cycle_number
      start.floor
    end

    def intersection(other)
      other_span = coerce_span(other)
      intersection_start = [start, other_span.start].max
      intersection_stop = [stop, other_span.stop].min

      return nil if intersection_start >= intersection_stop

      self.class.new(intersection_start, intersection_stop)
    end

    def includes?(time)
      normalized_time = coerce_time(time)
      start <= normalized_time && normalized_time < stop
    end

    def each_cycle_span(max_cycles: nil)
      return enum_for(:each_cycle_span, max_cycles: max_cycles) unless block_given?
      return self if duration.zero?

      current_start = start
      emitted = 0

      while current_start < stop
        if max_cycles && emitted >= max_cycles
          raise ArgumentError, "span crosses more than #{max_cycles} cycles"
        end

        cycle_boundary = [Rational(current_start.floor + 1), stop].min
        yield self.class.new(current_start, cycle_boundary)
        current_start = cycle_boundary
        emitted += 1
      end

      self
    end

    def cycle_spans(max_cycles: nil)
      each_cycle_span(max_cycles: max_cycles).to_a
    end

    def shift(amount)
      normalized_amount = coerce_time(amount)

      self.class.new(start + normalized_amount, stop + normalized_amount)
    end

    def scale(factor)
      normalized_factor = coerce_time(factor)
      raise ArgumentError, "scale factor must be non-negative" if normalized_factor.negative?

      self.class.new(start * normalized_factor, stop * normalized_factor)
    end

    def reverse_within(cycle_start, cycle_length = 1)
      normalized_start = coerce_time(cycle_start)
      normalized_length = coerce_time(cycle_length)
      raise ArgumentError, "cycle length must be positive" unless normalized_length.positive?

      mirror = (normalized_start * 2) + normalized_length

      self.class.new(mirror - stop, mirror - start)
    end

    def ==(other)
      other.is_a?(self.class) && start == other.start && stop == other.stop
    end

    alias eql? ==

    def hash
      [self.class, start, stop].hash
    end

    def to_s
      "[#{start}, #{stop})"
    end

    private

    def coerce_time(value)
      return value if value.is_a?(Rational)
      return Rational(value.to_s) if value.is_a?(Float)

      Rational(value)
    rescue ArgumentError, TypeError => error
      raise ArgumentError, "invalid time value #{value.inspect}: #{error.message}"
    end

    def coerce_span(value)
      return value if value.is_a?(self.class)
      return self.class.new(value.fetch(0), value.fetch(1)) if value.respond_to?(:fetch)

      raise ArgumentError, "expected #{self.class}, got #{value.class}"
    end
  end
end
