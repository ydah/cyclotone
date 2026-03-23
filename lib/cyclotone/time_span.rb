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
      intersection_start = [start, other.start].max
      intersection_stop = [stop, other.stop].min

      return nil if intersection_start >= intersection_stop

      self.class.new(intersection_start, intersection_stop)
    end

    def includes?(time)
      normalized_time = coerce_time(time)
      start <= normalized_time && normalized_time < stop
    end

    def cycle_spans
      return [] if duration.zero?

      spans = []
      current_start = start

      while current_start < stop
        cycle_boundary = [Rational(current_start.floor + 1), stop].min
        spans << self.class.new(current_start, cycle_boundary)
        current_start = cycle_boundary
      end

      spans
    end

    def shift(amount)
      normalized_amount = coerce_time(amount)

      self.class.new(start + normalized_amount, stop + normalized_amount)
    end

    def scale(factor)
      normalized_factor = coerce_time(factor)

      self.class.new(start * normalized_factor, stop * normalized_factor)
    end

    def reverse_within(cycle_start, cycle_length = 1)
      normalized_start = coerce_time(cycle_start)
      normalized_length = coerce_time(cycle_length)
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

      Rational(value)
    end
  end
end
