# frozen_string_literal: true

require "fileutils"

module Cyclotone
  module Backends
    class MIDIFileBackend
      include MIDIMessageSupport

      DEFAULT_BPM = 120
      DEFAULT_PPQN = 480
      DEFAULT_TRACK_NAME = "Cyclotone"
      TEMPO_EVENT_PRIORITY = -30
      TIME_SIGNATURE_EVENT_PRIORITY = -20
      TRACK_NAME_EVENT_PRIORITY = -10
      END_OF_TRACK_PRIORITY = 99

      attr_reader :path, :channel, :ppqn, :bpm, :track_mode

      def self.bpm_from_cps(cps, beats_per_cycle: 4)
        cps.to_f * 60.0 * beats_per_cycle.to_f
      end

      def initialize(
        path:,
        bpm: DEFAULT_BPM,
        ppqn: DEFAULT_PPQN,
        channel: 0,
        track_name: DEFAULT_TRACK_NAME,
        time_signature: [4, 4],
        track_mode: :single
      )
        @path = path
        @bpm = normalize_bpm(bpm)
        @ppqn = normalize_positive_integer(ppqn, "ppqn")
        @channel = channel.to_i
        @track_name = track_name.to_s
        @time_signature = normalize_time_signature(time_signature)
        @track_mode = track_mode.to_sym
        @messages = []
        @tempo_changes = []
        @time_signature_changes = []
        @origin_time = nil
      end

      def begin_capture(at:)
        @origin_time = at.to_f
        self
      end

      def end_capture
        self
      end

      def clear
        @messages.clear
        @tempo_changes.clear
        @time_signature_changes.clear
        @origin_time = nil
        self
      end

      def tempo_change(at:, bpm:)
        @tempo_changes << { at: at.to_f, bpm: normalize_bpm(bpm) }
        self
      end

      def time_signature_change(at:, numerator:, denominator:)
        signature = normalize_time_signature([numerator, denominator])
        @time_signature_changes << { at: at.to_f, signature: signature }
        self
      end

      def send_event(event, at: Time.now.to_f, cps: nil, slot_id: nil, **_options)
        capture_time = at.to_f
        @origin_time ||= capture_time

        messages_for(event, cps: cps).each do |message|
          @messages << normalize_message(message, capture_time, slot_id)
        end

        self
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      def write!
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, midi_file_data)
        path
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      def flush
        clear
      end

      def close
        self
      end

      def panic
        self
      end

      def midi_file_data
        tracks = track_payloads
        header_chunk(tracks.length) + tracks.map { |data| track_chunk(data) }.join
      end

      private

      def normalize_message(message, capture_time, slot_id)
        timestamp = capture_time + message.fetch(:delay, 0).to_f
        message.except(:delay).merge(at: timestamp, track: track_key(slot_id))
      end

      def header_chunk(track_count)
        format = track_count > 1 ? 1 : 0
        "MThd".b << [6, format, track_count, ppqn].pack("Nnnn")
      end

      def track_chunk(data)
        "MTrk".b << [data.bytesize].pack("N") << data
      end

      def track_payloads
        return [track_data(@messages, @track_name)] unless track_mode == :slot

        grouped = @messages.group_by { |message| message[:track] }
        return [track_data([], @track_name)] if grouped.empty?

        grouped.sort_by { |track, _| track.to_s }.map do |track, messages|
          track_data(messages, "#{@track_name}:#{track}")
        end
      end

      def track_data(messages, track_name)
        previous_tick = 0
        body = +"".b

        track_events(messages, track_name).each do |track_event|
          delta = track_event[:tick] - previous_tick
          body << encode_variable_length(delta)
          body << track_event[:data]
          previous_tick = track_event[:tick]
        end

        body
      end

      def track_events(messages, track_name)
        events = [
          { tick: 0, priority: TEMPO_EVENT_PRIORITY, data: tempo_event(bpm) },
          { tick: 0, priority: TIME_SIGNATURE_EVENT_PRIORITY, data: time_signature_event(@time_signature) },
          { tick: 0, priority: TRACK_NAME_EVENT_PRIORITY, data: track_name_event(track_name) }
        ]

        events.concat(tempo_change_events)
        events.concat(time_signature_change_events)
        events.concat(messages.map { |message| channel_track_event(message) })

        end_tick = events.map { |event| event[:tick] }.max || 0
        events << { tick: end_tick, priority: END_OF_TRACK_PRIORITY, data: end_of_track_event }
        events.sort_by { |event| [event[:tick], event[:priority]] }
      end

      def tempo_change_events
        @tempo_changes.map do |change|
          {
            tick: seconds_to_ticks(change[:at] - origin_time),
            priority: TEMPO_EVENT_PRIORITY,
            data: tempo_event(change[:bpm])
          }
        end
      end

      def time_signature_change_events
        @time_signature_changes.map do |change|
          {
            tick: seconds_to_ticks(change[:at] - origin_time),
            priority: TIME_SIGNATURE_EVENT_PRIORITY,
            data: time_signature_event(change[:signature])
          }
        end
      end

      def channel_track_event(message)
        tick = seconds_to_ticks(message[:at].to_f - origin_time)

        {
          tick: tick,
          priority: event_priority(message[:type]),
          data: channel_event_data(message)
        }
      end

      def event_priority(type)
        case type
        when :note_off then 0
        when :cc then 1
        else 2
        end
      end

      def origin_time
        @origin_time || 0.0
      end

      def seconds_to_ticks(seconds)
        elapsed = [seconds.to_f, 0.0].max
        current_bpm = bpm
        previous_elapsed = 0.0
        beats = 0.0

        sorted_tempo_changes.each do |change|
          change_elapsed = change[:at] - origin_time

          if change_elapsed <= previous_elapsed
            current_bpm = change[:bpm]
            next
          end

          break if change_elapsed >= elapsed

          beats += (change_elapsed - previous_elapsed) * current_bpm / 60.0
          previous_elapsed = change_elapsed
          current_bpm = change[:bpm]
        end

        beats += (elapsed - previous_elapsed) * current_bpm / 60.0
        (beats * ppqn).round
      end

      def sorted_tempo_changes
        @tempo_changes.sort_by { |change| change[:at] }
      end

      def channel_event_data(message)
        channel = message[:channel].to_i.clamp(0, 15)

        case message[:type]
        when :note_on
          [0x90 | channel, message[:note], message[:velocity]].pack("C3")
        when :note_off
          [0x80 | channel, message[:note], message[:velocity]].pack("C3")
        when :cc
          [0xB0 | channel, message[:controller], message[:value]].pack("C3")
        else
          raise ArgumentError, "unsupported MIDI message type: #{message[:type]}"
        end
      end

      def tempo_event(bpm_value)
        microseconds = (60_000_000 / bpm_value).round.clamp(1, 0xFF_FF_FF)
        "\xFF\x51\x03".b << [
          (microseconds >> 16) & 0xFF,
          (microseconds >> 8) & 0xFF,
          microseconds & 0xFF
        ].pack("C3")
      end

      def track_name_event(name_value)
        name = name_value.to_s.dup.force_encoding(Encoding::ASCII_8BIT)
        "\xFF\x03".b << encode_variable_length(name.bytesize) << name
      end

      def track_key(slot_id)
        return :default unless track_mode == :slot

        slot_id || :default
      end

      def time_signature_event(signature)
        numerator, denominator = signature
        exponent = denominator.bit_length - 1
        "\xFF\x58\x04".b << [numerator, exponent, 24, 8].pack("C4")
      end

      def end_of_track_event
        "\xFF\x2F\x00".b
      end

      def normalize_bpm(value)
        normalized = Float(value)
        return normalized if normalized.positive? && normalized.finite?

        raise ArgumentError, "bpm must be positive"
      rescue TypeError
        raise ArgumentError, "bpm must be numeric"
      end

      def normalize_positive_integer(value, name)
        normalized = Integer(value)
        return normalized if normalized.positive?

        raise ArgumentError, "#{name} must be positive"
      rescue TypeError
        raise ArgumentError, "#{name} must be an integer"
      end

      def normalize_time_signature(signature)
        values = Array(signature)
        raise ArgumentError, "time_signature must contain numerator and denominator" unless values.length == 2

        numerator = normalize_positive_integer(values[0], "time_signature numerator")
        denominator = normalize_positive_integer(values[1], "time_signature denominator")
        return [numerator, denominator] if power_of_two?(denominator)

        raise ArgumentError, "time_signature denominator must be a power of two"
      end

      def power_of_two?(value)
        value.nobits?(value - 1)
      end

      def encode_variable_length(value)
        number = value.to_i
        bytes = [number & 0x7F]
        number >>= 7

        while number.positive?
          bytes.unshift((number & 0x7F) | 0x80)
          number >>= 7
        end

        bytes.pack("C*")
      end
    end
  end
end
