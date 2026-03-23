# frozen_string_literal: true

require "singleton"
require "thread"

module Cyclotone
  class State
    include Singleton

    def initialize
      @values = {}
      @mutex = Mutex.new
    end

    def set_f(key, value)
      write(key, value.to_f)
    end

    def set_i(key, value)
      write(key, value.to_i)
    end

    def set_s(key, value)
      write(key, value.to_s)
    end

    def get_f(key)
      read(key)&.to_f
    end

    def get_i(key)
      read(key)&.to_i
    end

    def get_s(key)
      read(key)&.to_s
    end

    private

    def write(key, value)
      @mutex.synchronize { @values[key.to_sym] = value }
    end

    def read(key)
      @mutex.synchronize { @values[key.to_sym] }
    end
  end
end
