# frozen_string_literal: true

require_relative "midi_message_support"
require "thread"

begin
  require "unimidi"
rescue LoadError
end

module Cyclotone
  module Backends
    class MIDIBackend
      include MIDIMessageSupport

      attr_reader :channel

      def initialize(device_name: nil, channel: 0, output: nil, schedule: false, strict_output: false)
        @channel = channel.to_i
        @output = output || detect_output(device_name)
        @schedule = schedule
        @strict_output = strict_output
        @queue_mutex = Mutex.new
        @queue_cv = ConditionVariable.new
        @scheduled_messages = []
        @closed = false
      end

      class << self
        def available_outputs
          return [] unless defined?(UniMIDI)

          UniMIDI::Output.all
        rescue StandardError
          []
        end
      end

      def send_event(event, at: Time.now.to_f, cps: nil, **_options)
        ensure_output!

        if @schedule
          schedule_messages(messages_for(event, cps: cps), at: at)
        else
          messages_for(event, cps: cps).each { |message| emit(message.merge(at: at)) }
        end
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      def flush
        @queue_mutex.synchronize do
          @scheduled_messages.clear
          @queue_cv.signal
        end

        self
      end

      def close
        thread = nil
        @queue_mutex.synchronize do
          @closed = true
          @scheduled_messages.clear
          @queue_cv.broadcast
          thread = @scheduler_thread
        end

        thread&.join(0.5)
        self
      end

      def panic
        (0..15).each do |panic_channel|
          emit(type: :cc, channel: panic_channel, controller: 123, value: 0, at: Time.now.to_f)
          emit(type: :cc, channel: panic_channel, controller: 120, value: 0, at: Time.now.to_f)
        end

        self
      end

      private

      def ensure_output!
        raise ConnectionError, "MIDI output is not available" if @strict_output && @output.nil?
      end

      def emit(message)
        bytes = bytes_for(message)

        if @output.respond_to?(:call)
          @output.call(message)
        elsif midi_device?(@output)
          send_to_device(@output, bytes)
        elsif @output.respond_to?(:puts)
          @output.puts(message)
        end
      end

      def send_to_device(device, bytes)
        if device.respond_to?(:open)
          device.open do |port|
            (port || device).puts(bytes)
          end
        else
          device.puts(bytes)
        end
      end

      def midi_device?(output)
        output.respond_to?(:puts) && (output.respond_to?(:open) || !output.is_a?(IO))
      end

      def bytes_for(message)
        channel = normalize_channel(message[:channel] || channel)

        case message[:type]
        when :note_on
          [0x90 | channel, normalize_data_byte(message[:note]), normalize_velocity(message[:velocity])]
        when :note_off
          [0x80 | channel, normalize_data_byte(message[:note]), normalize_velocity(message[:velocity])]
        when :cc
          [0xB0 | channel, normalize_data_byte(message[:controller]), normalize_controller_value(message[:value])]
        else
          []
        end
      end

      def schedule_messages(messages, at:)
        ensure_scheduler_worker

        @queue_mutex.synchronize do
          messages.each do |message|
            scheduled_time = at + message.fetch(:delay, 0).to_f
            @scheduled_messages << message.reject { |key, _| key == :delay }.merge(at: scheduled_time)
          end

          @scheduled_messages.sort_by! { |message| message[:at] }
          @queue_cv.signal
        end
      end

      def ensure_scheduler_worker
        @queue_mutex.synchronize do
          return if @scheduler_thread&.alive?

          @closed = false
          @scheduler_thread = Thread.new { scheduler_loop }
        end
      end

      def scheduler_loop
        loop do
          message = next_scheduled_message
          return unless message

          emit(message)
        end
      end

      def next_scheduled_message
        @queue_mutex.synchronize do
          loop do
            return nil if @closed

            if @scheduled_messages.empty?
              @queue_cv.wait(@queue_mutex)
              next
            end

            wait_time = @scheduled_messages.first[:at] - Time.now.to_f
            if wait_time.positive?
              @queue_cv.wait(@queue_mutex, wait_time)
            else
              return @scheduled_messages.shift
            end
          end
        end
      end

      def detect_output(device_name)
        devices = self.class.available_outputs
        return nil if devices.empty?
        return devices.first if device_name.nil?

        devices.find { |device| device.name == device_name }
      end
    end
  end
end
