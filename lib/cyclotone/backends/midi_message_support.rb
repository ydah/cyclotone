# frozen_string_literal: true

module Cyclotone
  module Backends
    module MIDIMessageSupport
      def messages_for(event, cps: nil)
        values = event.value.is_a?(Hash) ? event.value : { note: event.value }
        return control_change_messages(values) if values.key?(:cc)

        notes = Array(values[:note])
        return [] if notes.empty? || notes.all?(&:nil?)

        active_channel = normalize_channel(values[:channel] || channel)
        sustain = [extract_sustain(values, event, cps), 0.0].max
        velocity_scale = values[:velocity_scale]
        attack_velocity = normalize_velocity(values[:velocity] || values[:gain] || 1.0, scale: velocity_scale)
        release_velocity = normalize_velocity(
          values.fetch(:release_velocity, 0),
          scale: values.fetch(:release_velocity_scale, velocity_scale)
        )

        notes.compact.flat_map do |note|
          [
            {
              type: :note_on,
              channel: active_channel,
              note: normalize_data_byte(note),
              velocity: attack_velocity
            },
            {
              type: :note_off,
              channel: active_channel,
              note: normalize_data_byte(note),
              velocity: release_velocity,
              delay: sustain
            }
          ]
        end
      end

      private

      def control_change_messages(values)
        cc_values = values[:cc].is_a?(Hash) ? values[:cc] : {}
        active_channel = normalize_channel(values[:channel] || channel)
        scale = values[:cc_scale] || values[:controller_scale]

        cc_values.sort_by { |controller, _| controller.to_i }.map do |controller, amount|
          {
            type: :cc,
            channel: active_channel,
            controller: normalize_data_byte(controller),
            value: normalize_controller_value(amount, scale: scale)
          }
        end
      end

      def extract_sustain(values, event, cps)
        if values.key?(:sustain_cycles)
          return values[:sustain_cycles].to_f / cps if cps.to_f.positive?

          return values[:sustain_cycles].to_f
        end

        sustain = values[:sustain]
        sustain = event.duration if sustain.nil?
        sustain ||= 1
        sustain.to_f
      end

      def normalize_velocity(value, scale: nil)
        normalize_7bit_value(value, scale: scale)
      end

      def normalize_controller_value(value, scale: nil)
        normalize_7bit_value(value, scale: scale)
      end

      def normalize_7bit_value(value, scale: nil)
        return normalize_data_byte(value) if scale == :midi
        return normalize_unit_7bit_value(value) if scale == :unit

        numeric = value.to_f
        return numeric.round.clamp(0, 127) if numeric > 1.0

        normalize_unit_7bit_value(numeric)
      end

      def normalize_unit_7bit_value(value)
        numeric = value.to_f
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
