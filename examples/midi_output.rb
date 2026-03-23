# frozen_string_literal: true

require "cyclotone"

begin
  require "unimidi"
rescue LoadError
  warn "Install unimidi first: gem install unimidi"
  exit 1
end

# Plays a MIDI melody for 16 seconds.
# Set CYCLOTONE_MIDI_DEVICE to pick a specific output, then run:
#   bundle exec ruby examples/midi_output.rb

device_name = ENV["CYCLOTONE_MIDI_DEVICE"]
channel = ENV.fetch("CYCLOTONE_MIDI_CHANNEL", "0").to_i

backend = Cyclotone::Backends::MIDIBackend.new(
  device_name: device_name,
  channel: channel,
  schedule: true
)
scheduler = Cyclotone::Scheduler.new(backend: backend, cps: Rational(1, 2))

melody = Cyclotone::Controls.note("0 2 4 7")
  .scale(:major, root: "c4")
  .velocity(0.75)
  .sustain(0.45)

scheduler.update_pattern(:m1, melody)
begin
  scheduler.start
  sleep 16
ensure
  scheduler&.stop
end
