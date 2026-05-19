# frozen_string_literal: true

require "thread"

module Cyclotone
  class Scheduler
    LOOKAHEAD = 0.3
    INTERVAL = 0.05
    DEFAULT_CPS = Rational(9, 16)
    SENT_RETAIN_CYCLES = 4
    SystemClock = Struct.new(:unused, keyword_init: true) do
      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def wall_time
        Time.now.to_f
      end
    end

    attr_reader :backend, :cps, :lookahead, :interval, :lookahead_cycles, :interval_cycles, :metrics

    def initialize(cps: DEFAULT_CPS, backend:, lookahead: LOOKAHEAD, interval: INTERVAL, lookahead_cycles: nil, interval_cycles: nil, logger: nil, retry_failed: false, clock: nil)
      @backend = backend
      @cps = normalize_cps(cps)
      @lookahead = lookahead
      @interval = interval
      @lookahead_cycles = lookahead_cycles&.to_f
      @interval_cycles = interval_cycles&.to_f
      @logger = logger
      @retry_failed = retry_failed
      @clock = clock || SystemClock.new
      @mutex = Mutex.new
      @patterns = {}
      @sent = {}
      @running = false
      @thread = nil
      @start_monotonic = monotonic_time
      @start_wall_time = wall_time
      @start_cycle = 0.0
      @last_cycle = 0.0
      @metrics = { ticks: 0, last_tick_duration: 0.0, max_tick_duration: 0.0 }
    end

    def start
      @mutex.synchronize do
        return self if @running

        @running = true
        @thread = Thread.new do
          Thread.current.abort_on_exception = false

          while running?
            tick_started = monotonic_time

            begin
              tick(tick_started)
            rescue StandardError => error
              log_runtime_error(error)
            end

            record_tick_duration(monotonic_time - tick_started)
            sleep(current_interval)
          end
        end
      end

      self
    end

    def stop(timeout: nil)
      thread = @mutex.synchronize do
        @running = false
        @thread
      end

      thread&.join(timeout)

      @mutex.synchronize do
        @thread = nil if @thread == thread && !thread&.alive?
      end

      self
    end

    def tick(now = monotonic_time)
      state = snapshot_state
      current_cycle = time_to_cycle(now, state[:cps], state[:start_cycle], state[:start_monotonic])
      logical_end = if lookahead_cycles
                      current_cycle + lookahead_cycles
                    else
                      time_to_cycle(now + lookahead, state[:cps], state[:start_cycle], state[:start_monotonic])
                    end
      dispatch_until(logical_end, state)
    end

    def update_pattern(slot_id, pattern, cps: nil, phase: 0)
      @mutex.synchronize do
        @patterns[slot_id] = {
          pattern: Pattern.ensure_pattern(pattern),
          cps: cps&.to_f,
          phase: Pattern.to_rational(phase)
        }
      end
    end

    def remove_pattern(slot_id)
      @mutex.synchronize do
        @patterns.delete(slot_id)
        @sent.delete_if { |key, _| key.first == slot_id }
      end
    end

    def setcps(value)
      normalized_cps = normalize_cps(value)
      now = monotonic_time
      wall_now = wall_time

      @mutex.synchronize do
        current_cycle = time_to_cycle(now, @cps, @start_cycle, @start_monotonic)

        @start_cycle = current_cycle
        @start_monotonic = now
        @start_wall_time = wall_now
        @cps = normalized_cps
      end
    end

    def reset_cycles
      set_cycle(0)
    end

    def set_cycle(value)
      @mutex.synchronize do
        @start_cycle = value.to_f
        @start_monotonic = monotonic_time
        @start_wall_time = wall_time
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
      @mutex.synchronize { @running }
    end

    def render(duration:)
      duration_value = duration.to_f
      raise ArgumentError, "render duration must be non-negative" if duration_value.negative?

      state = snapshot_state
      state[:backend].begin_capture(at: state[:start_wall_time]) if state[:backend].respond_to?(:begin_capture)

      logical_end = state[:start_cycle] + (duration_value * state[:cps])
      dispatch_until(logical_end, state)

      state[:backend].end_capture if state[:backend].respond_to?(:end_capture)
      state[:backend].write! if state[:backend].respond_to?(:write!)
      self
    end

    private

    def monotonic_time
      @clock.respond_to?(:monotonic_time) ? @clock.monotonic_time : @clock.call(:monotonic)
    end

    def wall_time
      @clock.respond_to?(:wall_time) ? @clock.wall_time : @clock.call(:wall)
    end

    def current_interval
      return interval unless interval_cycles

      interval_cycles / cps
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
      failed = false

      state[:patterns].each do |slot_id, slot|
        pattern = slot[:pattern]
        scale = slot_scale(slot, state[:cps])
        phase = slot[:phase]
        slot_span = TimeSpan.new((query_span.start * scale) + phase, (query_span.stop * scale) + phase)

        pattern.query_span(slot_span).each do |event|
          event = map_slot_event(event, scale, phase)
          next unless event.onset

          key = [slot_id, event.onset, event.value]
          next if sent?(key)

          absolute_time = state[:start_wall_time] + ((event.onset.to_f - state[:start_cycle]) / state[:cps])

          begin
            state[:backend].send_event(event, at: absolute_time, cps: state[:cps])
            mark_sent(key, logical_end)
          rescue StandardError => error
            failed = true
            log_runtime_error(error, slot_id: slot_id)
          end
        end
      end

      @mutex.synchronize { @last_cycle = logical_end unless failed && @retry_failed }
    end

    def sent?(key)
      @mutex.synchronize { @sent.key?(key) }
    end

    def mark_sent(key, logical_end)
      @mutex.synchronize do
        @sent[key] = logical_end
        prune_sent(logical_end)
      end
    end

    def prune_sent(logical_end)
      retain_after = logical_end - SENT_RETAIN_CYCLES
      @sent.delete_if { |_key, cycle| cycle < retain_after }
    end

    def record_tick_duration(duration)
      @mutex.synchronize do
        @metrics = {
          ticks: @metrics[:ticks] + 1,
          last_tick_duration: duration,
          max_tick_duration: [@metrics[:max_tick_duration], duration].max
        }
      end
    end

    def slot_scale(slot, global_cps)
      slot_cps = slot[:cps]
      return Rational(1) unless slot_cps&.positive?

      Rational(slot_cps.to_r) / Rational(global_cps.to_r)
    end

    def map_slot_event(event, scale, phase)
      return event if scale == 1 && phase.zero?

      Pattern.map_event(event) { |time| (time - phase) / scale }
    end

    def normalize_cps(value)
      normalized = value.to_f
      raise ArgumentError, "cps must be positive" unless normalized.positive?

      normalized
    end

    def time_to_cycle(time, cps_value, start_cycle, start_monotonic)
      start_cycle + ((time - start_monotonic) * cps_value)
    end

    def log_runtime_error(error, slot_id: nil)
      slot = slot_id ? " slot=#{slot_id}" : ""
      @logger&.call("[Cyclotone::Scheduler#{slot}] #{error.class}: #{error.message}")
    end
  end
end
