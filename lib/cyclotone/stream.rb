# frozen_string_literal: true

require "set"

module Cyclotone
  class Stream
    include Transition

    class << self
      def instance
        @instance ||= new
      end
    end

    attr_reader :scheduler, :fallback_error

    def initialize(backend: nil, scheduler: nil)
      @slots = {}
      @slot_options = {}
      @transitions = {}
      @muted = Set.new
      @soloed = Set.new
      @fallback_error = nil
      @scheduler = scheduler || Scheduler.new(backend: backend || default_backend)
    rescue StandardError => error
      @fallback_error = error
      @scheduler = Scheduler.new(backend: Backends::NullBackend.new)
    end

    def d(slot_id, pattern, cps: nil, phase: 0)
      assign(normalize_d_slot_id(slot_id), pattern, cps: cps, phase: phase)
    end

    def p(name, pattern, cps: nil, phase: 0)
      assign(normalize_slot_reference(name), pattern, cps: cps, phase: phase)
    end

    def hush(mode: :silence)
      case mode
      when :silence
        @slots.keys.each { |slot_id| assign(slot_id, Pattern.silence) }
      when :mute
        @muted.merge(@slots.keys)
        sync_scheduler
      when :clear
        @slots.keys.each { |slot_id| @scheduler.remove_pattern(slot_id) }
        @slots.clear
        @slot_options.clear
        @transitions.clear
      else
        raise ArgumentError, "unknown hush mode #{mode}"
      end

      self
    end

    def solo(id)
      @soloed << normalize_slot_reference(id)
      sync_scheduler
    end

    def unsolo(id)
      @soloed.delete(normalize_slot_reference(id))
      sync_scheduler
    end

    def mute(id)
      @muted << normalize_slot_reference(id)
      sync_scheduler
    end

    def unmute(id)
      @muted.delete(normalize_slot_reference(id))
      sync_scheduler
    end

    def setcps(value)
      @scheduler.setcps(value)
      self
    end

    def reset_cycles
      @scheduler.reset_cycles
      self
    end

    def set_cycle(value)
      @scheduler.set_cycle(value)
      self
    end

    def use_backend(backend)
      @scheduler.backend = backend
      sync_scheduler
    end

    def start
      @scheduler.start
      self
    end

    def stop
      @scheduler.stop
      self
    end

    def running?
      @scheduler.running?
    end

    def trigger
      wait_until_cycle(@scheduler.current_cycle + (@scheduler.interval * @scheduler.cps))
    end

    def qtrigger
      wait_until_cycle(@scheduler.current_cycle.ceil)
    end

    def mtrigger(period)
      normalized_period = period.to_i
      raise ArgumentError, "mtrigger period must be positive" unless normalized_period.positive?

      current_cycle = @scheduler.current_cycle
      next_cycle = current_cycle.ceil
      remainder = next_cycle % normalized_period
      target_cycle = remainder.zero? ? next_cycle : next_cycle + (normalized_period - remainder)

      wait_until_cycle(target_cycle)
    end

    def slot(slot_id)
      normalized = normalize_slot_reference(slot_id)
      simplify_completed_transition(normalized)
      @slots[normalized]
    end

    private

    def assign(slot_id, pattern, cps: nil, phase: 0)
      @slots[slot_id] = normalize_pattern(pattern)
      @slot_options[slot_id] = { cps: cps, phase: phase }
      @transitions.delete(slot_id)
      sync_scheduler
      @slots[slot_id]
    end

    def assign_transition(slot_id, pattern, replacement:, finish_cycle:)
      @slots[slot_id] = normalize_pattern(pattern)
      @transitions[slot_id] = { replacement: replacement, finish_cycle: finish_cycle }
      sync_scheduler
      @slots[slot_id]
    end

    def pattern_for_transition(slot_id)
      simplify_completed_transition(slot_id)
      @slots[slot_id] || Pattern.silence
    end

    def simplify_completed_transition(slot_id)
      transition = @transitions[slot_id]
      return unless transition
      return if @scheduler.current_cycle < transition[:finish_cycle].to_f

      @slots[slot_id] = transition[:replacement]
      @transitions.delete(slot_id)
      sync_scheduler
    end

    def normalize_pattern(pattern)
      return pattern if pattern.is_a?(Pattern)
      return Pattern.mn(pattern) if pattern.is_a?(String)

      Pattern.pure(pattern)
    end

    def normalize_d_slot_id(slot_id)
      normalize_slot_id(slot_id, force_d: true)
    end

    def normalize_slot_reference(slot_id)
      normalize_slot_id(slot_id, force_d: false)
    end

    def normalize_slot_id(slot_id, force_d:)
      raw = slot_id.to_s
      return raw.to_sym if raw.match?(/\Ad\d+\z/)
      return :"d#{raw}" if raw.match?(/\A\d+\z/)

      force_d ? :"d#{raw}" : raw.to_sym
    end

    def default_backend
      Backends::OSCBackend.new(socket: UDPSocket.new)
    end

    def sync_scheduler
      active_slots.each do |slot_id, pattern|
        options = @slot_options.fetch(slot_id, {})
        @scheduler.update_pattern(slot_id, pattern, cps: options[:cps], phase: options[:phase] || 0)
      end

      inactive_slots.each do |slot_id|
        @scheduler.remove_pattern(slot_id)
      end

      self
    end

    def active_slots
      if @soloed.empty?
        @slots.reject { |slot_id, _| @muted.include?(slot_id) }
      else
        @slots.select { |slot_id, _| @soloed.include?(slot_id) && !@muted.include?(slot_id) }
      end
    end

    def inactive_slots
      @slots.keys - active_slots.keys
    end

    def wait_until_cycle(target_cycle)
      cycles_remaining = target_cycle.to_f - @scheduler.current_cycle
      seconds = cycles_remaining / @scheduler.cps
      sleep(seconds) if seconds.positive?
      self
    end

    NullBackend = Backends::NullBackend
  end
end
