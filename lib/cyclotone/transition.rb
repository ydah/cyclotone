# frozen_string_literal: true

module Cyclotone
  module Transition
    DEFAULT_DURATION = 2

    def xfade(id, pattern)
      xfade_in(id, DEFAULT_DURATION, pattern)
    end

    def xfade_in(id, cycles, pattern)
      slot_id = normalize_slot_reference(id)
      current = @slots[slot_id] || Pattern.silence
      replacement = Pattern.ensure_pattern(pattern)
      duration = Pattern.to_rational(cycles)
      return assign(slot_id, replacement) if duration <= 0

      start_cycle = transition_start_cycle

      mixed = Pattern.stack([
        apply_gain_envelope(current, start_cycle: start_cycle, duration: duration, direction: :out),
        apply_gain_envelope(replacement, start_cycle: start_cycle, duration: duration, direction: :in)
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
      assign(normalize_slot_reference(id), pattern)
    end

    def jump_in(id, cycles, pattern)
      slot_id = normalize_slot_reference(id)
      current = @slots[slot_id] || Pattern.silence
      replacement = Pattern.ensure_pattern(pattern)
      switch_cycle = transition_start_cycle + Pattern.to_rational(cycles)
      return assign(slot_id, replacement) if switch_cycle <= transition_start_cycle

      delayed = Pattern.new { |span| split_query(span, switch_cycle, current, replacement) }

      assign(slot_id, delayed)
    end

    def anticipate(id, pattern)
      jump_in(id, 8, pattern)
    end

    def fade_in(cycles)
      start_cycle = transition_start_cycle
      duration = Pattern.to_rational(cycles)
      return self if duration <= 0

      @slots.keys.each do |slot_id|
        assign(slot_id, apply_gain_envelope(@slots.fetch(slot_id), start_cycle: start_cycle, duration: duration, direction: :in))
      end

      self
    end

    def fade_out(cycles)
      start_cycle = transition_start_cycle
      duration = Pattern.to_rational(cycles)
      return self if duration <= 0

      @slots.keys.each do |slot_id|
        assign(slot_id, apply_gain_envelope(@slots.fetch(slot_id), start_cycle: start_cycle, duration: duration, direction: :out))
      end

      self
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
        next event unless event.value.is_a?(Hash)

        time = event.onset || event.part.start
        value = event.value.dup
        envelope = value.delete(:gain_envelope)
        current_gain = value[:gain] || 1.0
        value[:gain] = current_gain * envelope.call(time)
        event.with_value(value)
      end
    end

    def split_query(span, switch_cycle, current, replacement)
      if span.stop <= switch_cycle
        current.query_span(span)
      elsif span.start >= switch_cycle
        replacement.query_span(span)
      else
        before = current.query_span(TimeSpan.new(span.start, switch_cycle))
        after = replacement.query_span(TimeSpan.new(switch_cycle, span.stop))
        Pattern.sort_events(before + after)
      end
    end

    def transition_start_cycle
      Pattern.to_rational(@scheduler.current_cycle.floor)
    end
  end
end
