# frozen_string_literal: true

module Cyclotone
  module Transition
    DEFAULT_DURATION = 2

    def xfade(id, pattern)
      xfade_in(id, DEFAULT_DURATION, pattern)
    end

    def xfade_in(id, cycles, pattern)
      slot_id = normalize_slot_reference(id)
      current = pattern_for_transition(slot_id)
      replacement = Pattern.ensure_pattern(pattern)
      duration = Pattern.to_rational(cycles)
      return assign(slot_id, replacement) if duration <= 0

      start_cycle = transition_start_cycle

      mixed = Pattern.stack(
        [
          apply_gain_envelope(current, start_cycle: start_cycle, duration: duration, direction: :out),
          apply_gain_envelope(replacement, start_cycle: start_cycle, duration: duration, direction: :in)
        ]
      )

      assign_transition(slot_id, mixed, replacement: replacement, finish_cycle: start_cycle + duration)
    end

    def clutch(id, pattern)
      clutch_in(id, DEFAULT_DURATION, pattern)
    end

    def clutch_in(id, cycles, pattern)
      slot_id = normalize_slot_reference(id)
      current = pattern_for_transition(slot_id)
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

      assign_transition(slot_id, swapped, replacement: replacement, finish_cycle: start_cycle + duration)
    end

    def interpolate(id, pattern)
      interpolate_in(id, 4, pattern)
    end

    def interpolate_in(id, cycles, pattern)
      slot_id = normalize_slot_reference(id)
      current = pattern_for_transition(slot_id)
      replacement = Pattern.ensure_pattern(pattern)
      duration = Pattern.to_rational(cycles)
      return assign(slot_id, replacement) if duration <= 0

      start_cycle = transition_start_cycle
      morphed = Pattern.new do |span|
        source_events = current.query_span(span)
        target_events = replacement.query_span(span)

        transition_anchor_times(source_events, target_events).filter_map do |time|
          source_event = event_at_time(source_events, time)
          target_event = event_at_time(target_events, time)
          base_event = target_event || source_event
          next unless base_event

          progress = transition_progress(time, start_cycle, duration)
          base_event.with_value(interpolate_value(source_event&.value, target_event&.value, progress))
        end.then { |events| Pattern.sort_events(events) }
      end

      assign_transition(slot_id, morphed, replacement: replacement, finish_cycle: start_cycle + duration)
    end

    def jump(id, pattern)
      assign(normalize_slot_reference(id), pattern)
    end

    def jump_in(id, cycles, pattern)
      slot_id = normalize_slot_reference(id)
      current = pattern_for_transition(slot_id)
      replacement = Pattern.ensure_pattern(pattern)
      switch_cycle = transition_start_cycle + Pattern.to_rational(cycles)
      return assign(slot_id, replacement) if switch_cycle <= transition_start_cycle

      delayed = Pattern.new { |span| split_query(span, switch_cycle, current, replacement) }

      assign_transition(slot_id, delayed, replacement: replacement, finish_cycle: switch_cycle)
    end

    def anticipate(id, pattern)
      jump_in(id, 8, pattern)
    end

    def fade_in(cycles)
      start_cycle = transition_start_cycle
      duration = Pattern.to_rational(cycles)
      return self if duration <= 0

      @slots.each_key do |slot_id|
        replacement = @slots.fetch(slot_id)
        assign_transition(
          slot_id,
          apply_gain_envelope(replacement, start_cycle: start_cycle, duration: duration, direction: :in),
          replacement: replacement,
          finish_cycle: start_cycle + duration
        )
      end

      self
    end

    def fade_out(cycles)
      start_cycle = transition_start_cycle
      duration = Pattern.to_rational(cycles)
      return self if duration <= 0

      @slots.each_key do |slot_id|
        assign_transition(
          slot_id,
          apply_gain_envelope(@slots.fetch(slot_id), start_cycle: start_cycle, duration: duration, direction: :out),
          replacement: Pattern.silence,
          finish_cycle: start_cycle + duration
        )
      end

      self
    end

    private

    def apply_gain_envelope(pattern, start_cycle:, duration:, direction:)
      Pattern.ensure_pattern(pattern).map_events do |event|
        time = event.onset || event.part.start
        progress = transition_progress(time, start_cycle, duration)
        factor = direction == :in ? progress : 1.0 - progress
        value = event.value.is_a?(Hash) ? event.value.dup : { value: event.value }
        current_gain = value.key?(:gain) ? value[:gain] : 1.0
        value[:gain] = current_gain * factor
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

    def transition_anchor_times(source_events, target_events)
      (source_events + target_events).map { |event| event.onset || event.part.start }.uniq.sort
    end

    def event_at_time(events, time)
      events.find { |event| event.covers_time?(time) }
    end

    def clutch_source(slot_id, time, _value, start_cycle, duration)
      progress = transition_progress(time, start_cycle, duration)
      chosen = Support::Deterministic.float(:clutch, slot_id, time) < progress

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
      (source.keys | target.keys).to_h do |key|
        value =
          if source.key?(key) && target.key?(key)
            interpolate_value(source[key], target[key], progress)
          else
            progress < 0.5 ? source.fetch(key, target[key]) : target.fetch(key, source[key])
          end

        [key, value]
      end
    end
  end
end
