# frozen_string_literal: true

module Cyclotone
  module Backends
    module MIDIMessageSupport
      def messages_for(event)
        values = event.value.is_a?(Hash) ? event.value : { note: event.value }
        return control_change_messages(values) if values.key?(:cc)

        note = values[:note]
        return [] if note.nil?

        active_channel = normalize_channel(values[:channel] || channel)
        sustain = [extract_sustain(values, event), 0.0].max

        [
          {
            type: :note_on,
            channel: active_channel,
            note: normalize_data_byte(note),
            velocity: normalize_velocity(values[:velocity] || values[:gain] || 1.0)
          },
          {
            type: :note_off,
            channel: active_channel,
            note: normalize_data_byte(note),
            velocity: 0,
            delay: sustain
          }
        ]
      end

      private

      def control_change_messages(values)
        cc_values = values[:cc].is_a?(Hash) ? values[:cc] : {}
        active_channel = normalize_channel(values[:channel] || channel)

        cc_values.map do |controller, amount|
          {
            type: :cc,
            channel: active_channel,
            controller: normalize_data_byte(controller),
            value: normalize_controller_value(amount)
          }
        end
      end

      def extract_sustain(values, event)
        sustain = values[:sustain]
        sustain = event.duration if sustain.nil?
        sustain ||= 1
        sustain.to_f
      end

      def normalize_velocity(value)
        normalize_7bit_value(value)
      end

      def normalize_controller_value(value)
        normalize_7bit_value(value)
      end

      def normalize_7bit_value(value)
        numeric = value.to_f
        return numeric.round.clamp(0, 127) if numeric > 1.0

        (numeric * 127).round.clamp(0, 127)
      end

      def normalize_channel(value)
        value.to_i.clamp(0, 15)
      end

      def normalize_data_byte(value)
        value.to_i.clamp(0, 127)
      end
    end
  end
end
