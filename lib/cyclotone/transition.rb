# frozen_string_literal: true

module Cyclotone
  module Transition
    DEFAULT_DURATION = 2

    def xfade(id, pattern)
      xfade_in(id, DEFAULT_DURATION, pattern)
    end

    def xfade_in(id, cycles, pattern)
      slot_id = normalize_slot_id(id)
      current = @slots[slot_id] || Pattern.silence
      replacement = Pattern.ensure_pattern(pattern)
      start_cycle = @scheduler.instance_variable_get(:@last_cycle).floor

      mixed = Pattern.stack([
        apply_gain_envelope(current, start_cycle: start_cycle, duration: cycles, direction: :out),
        apply_gain_envelope(replacement, start_cycle: start_cycle, duration: cycles, direction: :in)
      ])

      assign(slot_id, mixed)
    end

    def clutch(id, pattern)
      clutch_in(id, DEFAULT_DURATION, pattern)
    end

    def clutch_in(id, cycles, pattern)
      xfade_in(id, cycles, Pattern.ensure_pattern(pattern).degrade_by(0.5))
    end

    def interpolate(id, pattern)
      interpolate_in(id, 4, pattern)
    end

    def interpolate_in(id, cycles, pattern)
      xfade_in(id, cycles, pattern)
    end

    def jump(id, pattern)
      assign(normalize_slot_id(id), pattern)
    end

    def jump_in(id, cycles, pattern)
      slot_id = normalize_slot_id(id)
      current = @slots[slot_id] || Pattern.silence
      delayed = Pattern.new do |span|
        if span.cycle_number < cycles
          current.query_span(span)
        else
          Pattern.ensure_pattern(pattern).query_span(span)
        end
      end

      assign(slot_id, delayed)
    end

    def anticipate(id, pattern)
      jump_in(id, 8, pattern)
    end

    private

    def apply_gain_envelope(pattern, start_cycle:, duration:, direction:)
      Pattern.ensure_pattern(pattern).fmap do |value|
        next value unless value.is_a?(Hash)

        factor = lambda do |time|
          progress = ((time - start_cycle.to_f) / duration.to_f).clamp(0.0, 1.0)
          direction == :in ? progress : 1.0 - progress
        end

        value.merge(gain_envelope: factor)
      end.map_events do |event|
        time = event.onset || event.part.start
        value = event.value.dup
        envelope = value.delete(:gain_envelope)
        current_gain = value[:gain] || 1.0
        value[:gain] = current_gain * envelope.call(time)
        event.with_value(value)
      end
    end
  end
end
