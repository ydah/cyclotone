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
      assign(normalize_slot_id(slot_id), pattern)
    end

    def p(name, pattern)
      assign(name.to_sym, pattern)
    end

    def hush
      @slots.keys.each { |slot_id| assign(slot_id, Pattern.silence) }
      self
    end

    def solo(id)
      @soloed << normalize_slot_id(id)
      sync_scheduler
    end

    def unsolo(id)
      @soloed.delete(normalize_slot_id(id))
      sync_scheduler
    end

    def mute(id)
      @muted << normalize_slot_id(id)
      sync_scheduler
    end

    def unmute(id)
      @muted.delete(normalize_slot_id(id))
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

    def slot(slot_id)
      @slots[normalize_slot_id(slot_id)]
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

    def normalize_slot_id(slot_id)
      slot_id.to_s.start_with?("d") ? slot_id.to_s.to_sym : :"d#{slot_id}"
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

    class NullBackend
      attr_reader :events

      def initialize
        @events = []
      end

      def send_event(event, at:)
        @events << { event: event, at: at }
      end
    end
  end
end
