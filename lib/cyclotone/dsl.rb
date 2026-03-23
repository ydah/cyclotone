# frozen_string_literal: true

module Cyclotone
  module DSL
    Controls::ALIASES.each_key do |name|
      define_method(name) do |pattern_or_value = nil|
        Controls.public_send(name, pattern_or_value)
      end
    end

    %i[sine cosine tri saw isaw square rand irand perlin range smooth].each do |name|
      define_method(name) do |*args|
        Oscillators.public_send(name, *args)
      end
    end

    def stream
      Stream.instance
    end

    (1..16).each do |index|
      define_method(:"d#{index}") do |pattern = nil, &block|
        target_pattern = block ? block.call : pattern
        stream.d(index, target_pattern)
      end
    end

    def p(name, pattern = nil, &block)
      target_pattern = block ? block.call : pattern
      stream.p(name, target_pattern)
    end

    def hush
      stream.hush
    end

    def setcps(value)
      stream.setcps(value)
    end

    def reset_cycles
      stream.reset_cycles
    end

    def set_cycle(value)
      stream.set_cycle(value)
    end

    def xfade(id, pattern)
      stream.xfade(id, pattern)
    end

    def xfade_in(id, cycles, pattern)
      stream.xfade_in(id, cycles, pattern)
    end

    def jump(id, pattern)
      stream.jump(id, pattern)
    end

    def start
      stream.start
    end

    def stop
      stream.stop
    end

    def chord(name, root: 0)
      Harmony.chord(name, root: root)
    end

    def scale(name, pattern, root: 0)
      Harmony.scale(name, pattern, root: root)
    end
  end
end
