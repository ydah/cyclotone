# frozen_string_literal: true

require_relative "midi_message_support"

module Cyclotone
  module Backends
    class MIDIBackend
      include MIDIMessageSupport

      attr_reader :channel

      def initialize(device_name: nil, channel: 0, output: nil, schedule: false)
        @channel = channel.to_i
        @output = output || detect_output(device_name)
        @schedule = schedule
      end

      def send_event(event, at: Time.now.to_f, **_options)
        if @schedule
          schedule_messages(messages_for(event), at: at)
        else
          messages_for(event).each { |message| emit(message.merge(at: at)) }
        end
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      private

      def emit(message)
        if @output.respond_to?(:call)
          @output.call(message)
        elsif @output.respond_to?(:puts)
          @output.puts(message)
        end
      end

      def schedule_messages(messages, at:)
        Thread.new do
          sleep([at - Time.now.to_f, 0].max)

          messages.each do |message|
            delay = message[:delay].to_f

            if delay.positive?
              Thread.new do
                sleep(delay)
                emit(message.merge(at: at + delay))
              end
            else
              emit(message.merge(at: at))
            end
          end
        end
      end

      def detect_output(device_name)
        return nil unless defined?(UniMIDI)

        devices = UniMIDI::Output.all
        return devices.first if device_name.nil?

        devices.find { |device| device.name == device_name }
      rescue StandardError
        nil
      end
    end
  end
end
