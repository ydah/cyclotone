# frozen_string_literal: true

module Cyclotone
  class Event
    UNSET = Object.new.freeze

    attr_reader :whole, :part, :value

    def initialize(whole:, part:, value:)
      raise ArgumentError, "part must be a TimeSpan" unless part.is_a?(TimeSpan)
      raise ArgumentError, "whole must be nil or a TimeSpan" unless whole.nil? || whole.is_a?(TimeSpan)

      @whole = whole
      @part = part
      @value = deep_freeze(value)
      freeze
    end

    def onset
      whole&.start
    end

    def offset
      whole&.stop
    end

    def triggered?
      return false unless onset

      part.includes?(onset)
    end

    def duration
      whole&.duration
    end

    def has_whole?
      !whole.nil?
    end

    def active_span
      whole || part
    end

    def covers_time?(time)
      active_span.includes?(time)
    end

    def with_value(new_value)
      self.class.new(whole: whole, part: part, value: new_value)
    end

    def with_span(new_whole: UNSET, new_part: UNSET, whole: UNSET, part: UNSET)
      next_whole = whole.equal?(UNSET) ? (new_whole.equal?(UNSET) ? self.whole : new_whole) : whole
      next_part = part.equal?(UNSET) ? (new_part.equal?(UNSET) ? self.part : new_part) : part

      self.class.new(whole: next_whole, part: next_part, value: value)
    end

    def to_h
      { whole: whole, part: part, value: value }
    end

    def ==(other)
      other.is_a?(self.class) &&
        whole == other.whole &&
        part == other.part &&
        value == other.value
    end

    alias eql? ==

    def hash
      [self.class, whole, part, value].hash
    end

    private

    def deep_freeze(object)
      case object
      when Hash
        object.each_with_object({}) do |(key, entry), frozen_hash|
          frozen_hash[deep_freeze(key)] = deep_freeze(entry)
        end.freeze
      when Array
        object.map { |entry| deep_freeze(entry) }.freeze
      else
        object.freeze
      end
    end
  end
end
