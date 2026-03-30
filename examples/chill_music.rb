# frozen_string_literal: true

require "cyclotone"

# Writes a denser chill-style MIDI sketch for local playback or DAW import.
#   bundle exec ruby examples/chill_midi_output.rb

def part_from_phrases(phrases, velocity:, sustain:, channel:)
  Cyclotone::Pattern.cat(
    phrases.map { |phrase| Cyclotone::Controls.note(phrase) }
  ).velocity(velocity).sustain(sustain).channel(channel)
end

output_path = ENV.fetch("CYCLOTONE_MIDI_PATH", File.expand_path("../tmp/cyclotone_chill.mid", __dir__))
base_channel = ENV.fetch("CYCLOTONE_MIDI_CHANNEL", "0").to_i
cps = Rational(3, 8)
bpm = (cps * 240).to_f

backend = Cyclotone::Backends::MIDIFileBackend.new(
  path: output_path,
  bpm: bpm,
  channel: base_channel,
  track_name: "Cyclotone Chill Sketch"
)
scheduler = Cyclotone::Scheduler.new(backend: backend, cps: cps)

channels = {
  pads: base_channel % 16,
  bass: (base_channel + 1) % 16,
  keys: (base_channel + 2) % 16,
  sparkle: (base_channel + 3) % 16
}.freeze

pad_low = part_from_phrases(
  ["45 ~ ~ ~", "41 ~ ~ ~", "48 ~ ~ ~", "43 ~ ~ ~"],
  velocity: 0.30,
  sustain: 2.4,
  channel: channels[:pads]
)

pad_mid = part_from_phrases(
  ["60 ~ ~ ~", "57 ~ ~ ~", "64 ~ ~ ~", "59 ~ ~ ~"],
  velocity: 0.25,
  sustain: 2.2,
  channel: channels[:pads]
)

pad_high = part_from_phrases(
  ["67 ~ ~ ~", "64 ~ ~ ~", "71 ~ ~ ~", "64 ~ ~ ~"],
  velocity: 0.22,
  sustain: 2.0,
  channel: channels[:pads]
)

bass = part_from_phrases(
  [
    "45 ~ 45 52 45 ~ 45 55",
    "41 ~ 41 48 41 ~ 43 48",
    "48 ~ 48 55 48 ~ 50 55",
    "43 ~ 43 50 43 ~ 45 50"
  ],
  velocity: 0.62,
  sustain: 0.48,
  channel: channels[:bass]
)

keys = part_from_phrases(
  [
    "60 64 67 71 72 71 67 64",
    "57 60 64 67 69 67 64 60",
    "64 67 71 74 76 74 71 67",
    "59 62 64 69 71 69 64 62"
  ],
  velocity: 0.48,
  sustain: 0.32,
  channel: channels[:keys]
)

sparkle = part_from_phrases(
  [
    "~ 79 ~ 83 ~ 81 ~ 79",
    "~ 76 ~ 79 ~ 81 ~ 79",
    "~ 79 ~ 83 ~ 86 ~ 83",
    "~ 74 ~ 78 ~ 81 ~ 78"
  ],
  velocity: 0.34,
  sustain: 0.18,
  channel: channels[:sparkle]
)

scheduler.update_pattern(:pads_low, pad_low)
scheduler.update_pattern(:pads_mid, pad_mid)
scheduler.update_pattern(:pads_high, pad_high)
scheduler.update_pattern(:bass, bass)
scheduler.update_pattern(:keys, keys)
scheduler.update_pattern(:sparkle, sparkle)
scheduler.render(duration: 32)
backend.write!

puts "Wrote #{output_path}"
puts "Tempo: #{bpm.round(1)} BPM"
puts "Import the file into your DAW or MIDI player to audition the arrangement."
