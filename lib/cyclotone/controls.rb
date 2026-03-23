# frozen_string_literal: true

module Cyclotone
  module Controls
    CONTROL_DEFS = {
      s: { type: :string, aliases: [:sound] },
      n: { type: :integer },
      speed: { type: :float, default: 1.0 },
      begin: { type: :float, aliases: [:sample_begin] },
      end: { type: :float, aliases: [:sample_end] },
      pan: { type: :float, default: 0.5 },
      gain: { type: :float, default: 1.0 },
      amp: { type: :float, default: 1.0 },
      cut: { type: :integer },
      unit: { type: :string },
      accelerate: { type: :float },
      legato: { type: :float },
      attack: { type: :float, aliases: [:att] },
      hold: { type: :float },
      release: { type: :float, aliases: [:rel] },
      cutoff: { type: :float, aliases: [:lpf] },
      resonance: { type: :float, aliases: [:lpq] },
      hcutoff: { type: :float, aliases: [:hpf] },
      hresonance: { type: :float, aliases: [:hpq] },
      bandf: { type: :float, aliases: [:bpf] },
      bandq: { type: :float, aliases: [:bpq] },
      djf: { type: :float },
      vowel: { type: :string },
      delay: { type: :float },
      delaytime: { type: :float, aliases: [:delayt] },
      delayfeedback: { type: :float, aliases: [:delayfb] },
      lock: { type: :integer },
      dry: { type: :float },
      room: { type: :float },
      size: { type: :float, aliases: [:sz] },
      distort: { type: :float },
      triode: { type: :float },
      shape: { type: :float },
      squiz: { type: :float },
      crush: { type: :float },
      coarse: { type: :float },
      tremolorate: { type: :float, aliases: [:tremr] },
      tremolodepth: { type: :float, aliases: [:tremdp] },
      phaserrate: { type: :float, aliases: [:phasr] },
      phaserdepth: { type: :float, aliases: [:phasdp] },
      leslie: { type: :float },
      lrate: { type: :float },
      lsize: { type: :float },
      octer: { type: :float },
      octersub: { type: :float },
      octersubsub: { type: :float },
      fshift: { type: :float },
      fshiftnote: { type: :float },
      fshiftphase: { type: :float },
      ring: { type: :float },
      ringf: { type: :float },
      ringdf: { type: :float },
      note: { type: :integer },
      velocity: { type: :integer, default: 100 },
      sustain: { type: :float, default: 1.0 },
      channel: { type: :integer, default: 0 },
      cc: { type: :hash }
    }.freeze

    ALIASES = CONTROL_DEFS.each_with_object({}) do |(name, options), mapping|
      mapping[name] = name
      Array(options[:aliases]).each { |alias_name| mapping[alias_name] = name }
    end.freeze

    module_function

    CONTROL_DEFS.each_key do |name|
      define_method(name) do |pattern_or_value|
        factory(name, pattern_or_value)
      end

      Array(CONTROL_DEFS[name][:aliases]).each do |alias_name|
        define_method(alias_name) do |pattern_or_value|
          factory(name, pattern_or_value)
        end
      end
    end

    def control(name, pattern_or_value)
      factory(name, pattern_or_value)
    end

    def factory(name, pattern_or_value)
      canonical_name = canonical(name)
      pattern = coerce_pattern(pattern_or_value)

      pattern.fmap do |value|
        wrap_value(canonical_name, value)
      end
    end

    def coerce_pattern(pattern_or_value)
      return pattern_or_value if pattern_or_value.is_a?(Pattern)
      return Pattern.mn(pattern_or_value) if pattern_or_value.is_a?(String)

      Pattern.pure(pattern_or_value)
    end

    def wrap_value(control_name, value)
      if value.is_a?(Hash)
        if control_name == :s && (value.key?(:s) || value.key?(:n))
          value.merge(s: value[:s] || value[:value])
        elsif control_name == :note && value.key?(:note)
          value
        else
          value.merge(control_name => value[control_name] || value[:value] || value)
        end
      else
        { control_name => value }
      end
    end

    def canonical(name)
      ALIASES.fetch(name.to_sym) { raise InvalidControlError, "unknown control #{name}" }
    end
  end
end

module Cyclotone
  class Pattern
    Controls::CONTROL_DEFS.each_key do |name|
      define_method(name) do |pattern_or_value|
        merge(Controls.factory(name, pattern_or_value))
      end

      Array(Controls::CONTROL_DEFS[name][:aliases]).each do |alias_name|
        define_method(alias_name) do |pattern_or_value|
          merge(Controls.factory(name, pattern_or_value))
        end
      end
    end

    def control(name, pattern_or_value)
      merge(Controls.factory(name, pattern_or_value))
    end
  end
end
