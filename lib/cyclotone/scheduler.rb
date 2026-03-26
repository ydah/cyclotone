# frozen_string_literal: true

require "thread"

module Cyclotone
  class Scheduler
    LOOKAHEAD = 0.3
    INTERVAL = 0.05
    DEFAULT_CPS = Rational(9, 16)

    attr_reader :backend, :cps, :lookahead, :interval

    def initialize(cps: DEFAULT_CPS, backend:, lookahead: LOOKAHEAD, interval: INTERVAL, logger: nil)
      @backend = backend
      @cps = cps.to_f
      @lookahead = lookahead
      @interval = interval
      @logger = logger
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
          begin
            tick
          rescue StandardError => error
            log_runtime_error(error)
          end

          sleep(@interval)
        end
      end
    end

    def stop
      @running = false
      @thread&.join
    end

    def tick(now = monotonic_time)
      state = snapshot_state
      logical_end = time_to_cycle(now + lookahead, state[:cps], state[:start_cycle], state[:start_monotonic])
      dispatch_until(logical_end, state)
    end

    def update_pattern(slot_id, pattern)
      @mutex.synchronize { @patterns[slot_id] = Pattern.ensure_pattern(pattern) }
    end

    def remove_pattern(slot_id)
      @mutex.synchronize { @patterns.delete(slot_id) }
    end

    def setcps(value)
      now = monotonic_time
      wall_now = Time.now.to_f

      @mutex.synchronize do
        current_cycle = time_to_cycle(now, @cps, @start_cycle, @start_monotonic)

        @start_cycle = current_cycle
        @start_monotonic = now
        @start_wall_time = wall_now
        @cps = value.to_f
      end
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

    def current_cycle(now = monotonic_time)
      @mutex.synchronize { time_to_cycle(now, @cps, @start_cycle, @start_monotonic) }
    end

    def running?
      @running
    end

    def render(duration:)
      duration_value = duration.to_f
      raise ArgumentError, "render duration must be non-negative" if duration_value.negative?

      state = snapshot_state
      state[:backend].begin_capture(at: state[:start_wall_time]) if state[:backend].respond_to?(:begin_capture)

      logical_end = state[:start_cycle] + (duration_value * state[:cps])
      dispatch_until(logical_end, state)
      self
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def snapshot_state
      @mutex.synchronize do
        {
          patterns: @patterns.dup,
          cps: @cps,
          last_cycle: @last_cycle,
          start_cycle: @start_cycle,
          start_monotonic: @start_monotonic,
          start_wall_time: @start_wall_time,
          backend: @backend
        }
      end
    end

    def dispatch_until(logical_end, state)
      return if logical_end <= state[:last_cycle]

      query_span = TimeSpan.new(Rational(state[:last_cycle].to_r), Rational(logical_end.to_r))

      state[:patterns].each do |slot_id, pattern|
        pattern.query_span(query_span).each do |event|
          next unless event.onset

          key = [slot_id, event.onset, event.value]
          next if @sent[key]

          absolute_time = state[:start_wall_time] + ((event.onset.to_f - state[:start_cycle]) / state[:cps])
          state[:backend].send_event(event, at: absolute_time)
          @sent[key] = true
        rescue StandardError => error
          log_runtime_error(error)
        end
      end

      @mutex.synchronize { @last_cycle = logical_end }
    end

    def time_to_cycle(time, cps_value, start_cycle, start_monotonic)
      start_cycle + ((time - start_monotonic) * cps_value)
    end

    def log_runtime_error(error)
      @logger&.call("[Cyclotone::Scheduler] #{error.class}: #{error.message}")
    end
  end
end
