# frozen_string_literal: true

require "fileutils"

module Cyclotone
  module Backends
    class MIDIFileBackend
      include MIDIMessageSupport

      DEFAULT_BPM = 120
      DEFAULT_PPQN = 480
      DEFAULT_TRACK_NAME = "Cyclotone"

      attr_reader :path, :channel, :ppqn, :bpm

      def initialize(path:, bpm: DEFAULT_BPM, ppqn: DEFAULT_PPQN, channel: 0, track_name: DEFAULT_TRACK_NAME)
        @path = path
        @bpm = bpm.to_f
        @ppqn = ppqn.to_i
        @channel = channel.to_i
        @track_name = track_name.to_s
        @messages = []
        @origin_time = nil
      end

      def begin_capture(at:)
        @origin_time = at.to_f
        self
      end

      def clear
        @messages.clear
        @origin_time = nil
        self
      end

      def send_event(event, at: Time.now.to_f)
        capture_time = at.to_f
        @origin_time ||= capture_time

        messages_for(event).each do |message|
          @messages << normalize_message(message, capture_time)
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

      def midi_file_data
        header_chunk + track_chunk(track_data)
      end

      private

      def normalize_message(message, capture_time)
        timestamp = capture_time + message.fetch(:delay, 0).to_f
        message.reject { |key, _| key == :delay }.merge(at: timestamp)
      end

      def header_chunk
        "MThd".b << [6, 0, 1, ppqn].pack("Nnnn")
      end

      def track_chunk(data)
        "MTrk".b << [data.bytesize].pack("N") << data
      end

      def track_data
        previous_tick = 0
        body = +"".b

        track_events.each do |track_event|
          delta = track_event[:tick] - previous_tick
          body << encode_variable_length(delta)
          body << track_event[:data]
          previous_tick = track_event[:tick]
        end

        body
      end

      def track_events
        events = [
          { tick: 0, priority: 0, data: tempo_event },
          { tick: 0, priority: 1, data: track_name_event }
        ]

        events.concat(@messages.map { |message| channel_track_event(message) })

        end_tick = events.map { |event| event[:tick] }.max || 0
        events << { tick: end_tick, priority: 99, data: end_of_track_event }
        events.sort_by { |event| [event[:tick], event[:priority]] }
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
        beats = [seconds.to_f, 0.0].max * bpm / 60.0
        (beats * ppqn).round
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

      def tempo_event
        microseconds = (60_000_000 / bpm).round.clamp(1, 0xFF_FF_FF)
        "\xFF\x51\x03".b << [
          (microseconds >> 16) & 0xFF,
          (microseconds >> 8) & 0xFF,
          microseconds & 0xFF
        ].pack("C3")
      end

      def track_name_event
        name = @track_name.dup.force_encoding(Encoding::ASCII_8BIT)
        "\xFF\x03".b << encode_variable_length(name.bytesize) << name
      end

      def end_of_track_event
        "\xFF\x2F\x00".b
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
