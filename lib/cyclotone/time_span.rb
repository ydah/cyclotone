# frozen_string_literal: true

module Cyclotone
  class TimeSpan
    attr_reader :start, :stop

    def initialize(start_time, stop_time)
      @start = coerce_time(start_time)
      @stop = coerce_time(stop_time)

      return unless @stop < @start

      raise ArgumentError, "stop time must be greater than or equal to start time"
    end

    def duration
      stop - start
    end

    def midpoint
      (start + stop) / 2
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
