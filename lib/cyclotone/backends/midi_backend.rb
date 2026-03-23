# frozen_string_literal: true

module Cyclotone
  module Backends
    class MIDIBackend
      attr_reader :channel

      def initialize(device_name: nil, channel: 0, output: nil, schedule: false)
        @channel = channel.to_i
        @output = output || detect_output(device_name)
        @schedule = schedule
      end

      def send_event(event, at: Time.now.to_f)
        if @schedule
          schedule_messages(messages_for(event), at: at)
        else
          messages_for(event).each { |message| emit(message.merge(at: at)) }
        end
      rescue StandardError => error
        raise ConnectionError, error.message
      end

      def messages_for(event)
        values = event.value.is_a?(Hash) ? event.value : { note: event.value }
        note = values[:note]
        return control_change_messages(values) if values.key?(:cc)
        return [] if note.nil?

        velocity = ((values[:velocity] || values[:gain] || 1.0).to_f * 127).clamp(0, 127).to_i
        active_channel = (values[:channel] || channel).to_i
        sustain = values[:sustain] || event.duration || 1

        [
          { type: :note_on, channel: active_channel, note: note.to_i, velocity: velocity },
          { type: :note_off, channel: active_channel, note: note.to_i, velocity: 0, delay: sustain.to_f }
        ]
      end

      private

      def control_change_messages(values)
        cc_values = values[:cc].is_a?(Hash) ? values[:cc] : {}
        active_channel = (values[:channel] || channel).to_i

        cc_values.map do |controller, amount|
          { type: :cc, channel: active_channel, controller: controller.to_i, value: amount.to_i }
        end
      end

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
