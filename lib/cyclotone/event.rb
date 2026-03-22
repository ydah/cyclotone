# frozen_string_literal: true

module Cyclotone
  class Event
    attr_reader :whole, :part, :value

    def initialize(whole:, part:, value:)
      @whole = whole
      @part = part
      @value = value
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

    def with_value(new_value)
      self.class.new(whole: whole, part: part, value: new_value)
    end

    def with_span(new_whole: whole, new_part: part)
      self.class.new(whole: new_whole, part: new_part, value: value)
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
  end
end
