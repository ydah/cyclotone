# frozen_string_literal: true

require "singleton"
require "set"

module Cyclotone
  class Stream
    include Singleton
    include Transition

    attr_reader :scheduler

    def initialize
      @slots = {}
      @muted = Set.new
      @soloed = Set.new
      @scheduler = Scheduler.new(backend: Backends::OSCBackend.new(socket: UDPSocket.new))
    rescue StandardError
      @scheduler = Scheduler.new(backend: NullBackend.new)
    end

    def d(slot_id, pattern)
      assign(normalize_d_slot_id(slot_id), pattern)
    end

    def p(name, pattern)
      assign(normalize_slot_reference(name), pattern)
    end

    def hush
      @slots.keys.each { |slot_id| assign(slot_id, Pattern.silence) }
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
      normalized_period = [period.to_i, 1].max
      current_cycle = @scheduler.current_cycle
      next_cycle = current_cycle.ceil
      remainder = next_cycle % normalized_period
      target_cycle = remainder.zero? ? next_cycle : next_cycle + (normalized_period - remainder)

      wait_until_cycle(target_cycle)
    end

    def slot(slot_id)
      @slots[normalize_slot_reference(slot_id)]
    end

    private

    def assign(slot_id, pattern)
      @slots[slot_id] = normalize_pattern(pattern)
      sync_scheduler
      @slots[slot_id]
    end

    def normalize_pattern(pattern)
      return pattern if pattern.is_a?(Pattern)
      return Pattern.mn(pattern) if pattern.is_a?(String)

      Pattern.pure(pattern)
    end

    def normalize_d_slot_id(slot_id)
      raw = slot_id.to_s
      return raw.to_sym if raw.match?(/\Ad\d+\z/)
      return :"d#{raw}" if raw.match?(/\A\d+\z/)

      :"d#{raw}"
    end

    def normalize_slot_reference(slot_id)
      raw = slot_id.to_s
      return raw.to_sym if raw.match?(/\Ad\d+\z/)
      return :"d#{raw}" if raw.match?(/\A\d+\z/)

      raw.to_sym
    end

    def sync_scheduler
      active_slots.each do |slot_id, pattern|
        @scheduler.update_pattern(slot_id, pattern)
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

    class NullBackend
      attr_reader :events

      def initialize
        @events = []
      end

      def send_event(event, at:, **options)
        @events << { event: event, at: at, options: options }
      end
    end
  end
end
