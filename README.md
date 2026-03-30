# Cyclotone

Cyclotone is a Ruby gem for pattern-based live coding. It combines exact rational time, immutable event patterns, a compact mini-notation, and runtime tools for driving OSC or MIDI-based performance workflows.

## Highlights

- Exact timing with `Cyclotone::TimeSpan`
- Immutable `Cyclotone::Event` values and composable `Cyclotone::Pattern` queries
- Mini-notation parsing and compilation, including Euclidean rhythms
- Pattern transforms for time, concatenation, accumulation, alteration, condition, and sample operations
- Control factories, oscillators, and harmony helpers for building musical data
- Scheduler, stream transitions, and a DSL for slot-based live performance
- OSC, MIDI, and MIDI file backends

## Installation

Cyclotone requires Ruby 3.1 or newer.

Add it to your Gemfile:

```bash
bundle add cyclotone
```

Or install it directly:

```bash
gem install cyclotone
```

## Quick Start

### Query a pattern directly

```ruby
require "cyclotone"

beat = Cyclotone::Pattern.mn("bd [sd sd] hh cp")
accented = Cyclotone::Controls.s(beat).gain(0.9)

events = accented.query_cycle(0)

events.map { |event| [event.whole.to_s, event.part.to_s, event.value] }
# => [
#      ["[0, 1/4)", "[0, 1/4)", {:s=>"bd", :gain=>0.9}],
#      ...
#    ]
```

### Use the live coding DSL

```ruby
require "cyclotone"
include Cyclotone::DSL

setcps Rational(9, 16)

d1 s("bd sd:3 [~ bd] sd").gain(0.8)
d2 note("0 2 4 7").scale(:minor, root: "c4").s("superpiano")
d3 s("hh*8").every(4) { |pattern| pattern.fast(2) }.sometimes { |pattern| pattern.degrade }
```

## Run It Locally

### REPL

Start an interactive session with the DSL preloaded:

```bash
bundle exec bin/cyclotone
```

### Local MIDI file output

Generate a MIDI file without needing a live OSC target:

```bash
bundle exec ruby examples/midi_output.rb
bundle exec ruby examples/chill_midi_output.rb
```

These write `tmp/cyclotone_demo.mid` and `tmp/cyclotone_chill.mid`, which you can import into a DAW or any MIDI-capable player.

### OSC / SuperDirt examples

If you already have SuperCollider and SuperDirt running, try one of the example scripts:

```bash
bundle exec ruby examples/basic_beat.rb
bundle exec ruby examples/euclidean_rhythms.rb
bundle exec ruby examples/live_coding_session.rb
```

The OSC examples read `CYCLOTONE_OSC_HOST` and `CYCLOTONE_OSC_PORT` when you need to override the default target.

## Development

Install dependencies, run the test suite, and build the gem:

```bash
bundle install
bundle exec rspec
bundle exec rake yard
gem build cyclotone.gemspec
```

For local manual experiments, install the gem into your current Ruby environment:

```bash
bundle exec rake install
```

YARD output is written to `doc/yard`.

## Contributing

Bug reports and pull requests are welcome at https://github.com/ydah/cyclotone.

## License

Cyclotone is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
