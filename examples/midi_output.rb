# frozen_string_literal: true

require "cyclotone"

# Writes a Standard MIDI File for local playback or DAW import.
#   bundle exec ruby examples/midi_output.rb

output_path = ENV.fetch("CYCLOTONE_MIDI_PATH", File.expand_path("../tmp/cyclotone_demo.mid", __dir__))
channel = ENV.fetch("CYCLOTONE_MIDI_CHANNEL", "0").to_i
cps = Rational(1, 2)
bpm = (cps * 240).to_f

backend = Cyclotone::Backends::MIDIFileBackend.new(
  path: output_path,
  bpm: bpm,
  channel: channel,
  track_name: "Cyclotone Demo"
)
scheduler = Cyclotone::Scheduler.new(backend: backend, cps: cps)

melody = Cyclotone::Controls.note("0 2 4 7")
  .scale(:major, root: "c4")
  .velocity(0.75)
  .sustain(0.45)

scheduler.update_pattern(:m1, melody)
scheduler.render(duration: 16)
backend.write!

puts "Wrote #{output_path}"
puts "Import the file into your DAW or MIDI player to audition the pattern."
