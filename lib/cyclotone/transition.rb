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
      slot_id = normalize_slot_reference(id)
      current = @slots[slot_id] || Pattern.silence
      replacement = Pattern.ensure_pattern(pattern)
      duration = Pattern.to_rational(cycles)
      return assign(slot_id, replacement) if duration <= 0

      start_cycle = transition_start_cycle
      swapped = Pattern.new do |span|
        source_events = current.query_span(span).map { |event| [event, :current] }
        target_events = replacement.query_span(span).map { |event| [event, :replacement] }

        (source_events + target_events).filter_map do |event, source|
          time = event.onset || event.part.start
          desired_source = clutch_source(slot_id, time, event.value, start_cycle, duration)
          event if source == desired_source
        end.then { |events| Pattern.sort_events(events) }
      end

      assign(slot_id, swapped)
    end

    def interpolate(id, pattern)
      interpolate_in(id, 4, pattern)
    end

    def interpolate_in(id, cycles, pattern)
      slot_id = normalize_slot_reference(id)
      current = @slots[slot_id] || Pattern.silence
      replacement = Pattern.ensure_pattern(pattern)
      duration = Pattern.to_rational(cycles)
      return assign(slot_id, replacement) if duration <= 0

      start_cycle = transition_start_cycle
      morphed = Pattern.new do |span|
        anchor_times = Pattern.stack([current, replacement]).query_span(span).map do |event|
          event.onset || event.part.start
        end.uniq.sort

        anchor_times.filter_map do |time|
          source_event = current.query_event_at(time)
          target_event = replacement.query_event_at(time)
          base_event = target_event || source_event
          next unless base_event

          progress = transition_progress(time, start_cycle, duration)
          base_event.with_value(interpolate_value(source_event&.value, target_event&.value, progress))
        end.then { |events| Pattern.sort_events(events) }
      end

      assign(slot_id, morphed)
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

    def transition_progress(time, start_cycle, duration)
      ((time.to_f - start_cycle.to_f) / duration.to_f).clamp(0.0, 1.0)
    end

    def clutch_source(slot_id, time, value, start_cycle, duration)
      progress = transition_progress(time, start_cycle, duration)
      chosen = Support::Deterministic.float(:clutch, slot_id, time, value) < progress

      chosen ? :replacement : :current
    end

    def interpolate_value(source, target, progress)
      return source if target.nil?
      return target if source.nil?

      if source.is_a?(Numeric) && target.is_a?(Numeric)
        source.to_f + ((target.to_f - source.to_f) * progress)
      elsif source.is_a?(Hash) && target.is_a?(Hash)
        interpolate_hash(source, target, progress)
      else
        progress < 0.5 ? source : target
      end
    end

    def interpolate_hash(source, target, progress)
      (source.keys | target.keys).each_with_object({}) do |key, result|
        result[key] =
          if source.key?(key) && target.key?(key)
            interpolate_value(source[key], target[key], progress)
          else
            progress < 0.5 ? source.fetch(key, target[key]) : target.fetch(key, source[key])
          end
      end
    end
  end
end
