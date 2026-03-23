# frozen_string_literal: true

require "thread"

module Cyclotone
  class Scheduler
    LOOKAHEAD = 0.3
    INTERVAL = 0.05
    DEFAULT_CPS = Rational(9, 16)

    attr_reader :backend, :cps, :lookahead, :interval

    def initialize(cps: DEFAULT_CPS, backend:, lookahead: LOOKAHEAD, interval: INTERVAL)
      @backend = backend
      @cps = cps.to_f
      @lookahead = lookahead
      @interval = interval
      @mutex = Mutex.new
      @patterns = {}
      @sent = {}
      @running = false
      @start_monotonic = monotonic_time
      @start_wall_time = Time.now.to_f
      @start_cycle = 0.0
      @last_cycle = 0.0
    end

    def start
      return if @running

      @running = true
      @thread = Thread.new do
        while @running
          tick
          sleep(@interval)
        end
      end
    end

    def stop
      @running = false
      @thread&.join
    end

    def tick(now = monotonic_time)
      patterns_snapshot, cps_value, last_cycle, start_cycle, start_monotonic, start_wall_time = @mutex.synchronize do
        [@patterns.dup, @cps, @last_cycle, @start_cycle, @start_monotonic, @start_wall_time]
      end

      logical_end = time_to_cycle(now + lookahead, cps_value, start_cycle, start_monotonic)
      return if logical_end <= last_cycle

      query_span = TimeSpan.new(Rational(last_cycle.to_r), Rational(logical_end.to_r))

      patterns_snapshot.each do |slot_id, pattern|
        pattern.query_span(query_span).each do |event|
          next unless event.onset

          key = [slot_id, event.onset, event.value]
          next if @sent[key]

          absolute_time = start_wall_time + ((event.onset.to_f - start_cycle) / cps_value)
          backend.send_event(event, at: absolute_time)
          @sent[key] = true
        end
      end

      @mutex.synchronize { @last_cycle = logical_end }
    end

    def update_pattern(slot_id, pattern)
      @mutex.synchronize { @patterns[slot_id] = Pattern.ensure_pattern(pattern) }
    end

    def remove_pattern(slot_id)
      @mutex.synchronize { @patterns.delete(slot_id) }
    end

    def setcps(value)
      @mutex.synchronize { @cps = value.to_f }
    end

    def reset_cycles
      set_cycle(0)
    end

    def set_cycle(value)
      @mutex.synchronize do
        @start_cycle = value.to_f
        @start_monotonic = monotonic_time
        @start_wall_time = Time.now.to_f
        @last_cycle = value.to_f
        @sent.clear
      end
    end

    def backend=(backend)
      @mutex.synchronize { @backend = backend }
    end

    def running?
      @running
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def time_to_cycle(time, cps_value, start_cycle, start_monotonic)
      start_cycle + ((time - start_monotonic) * cps_value)
    end
  end
end
