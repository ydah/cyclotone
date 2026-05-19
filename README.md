# Cyclotone

Pattern-based live coding primitives for Ruby. Cyclotone provides rational-time spans, immutable pattern events, a compact mini-notation, and OSC/MIDI backends for music workflows.

## Requirements

- Ruby 3.1 or newer
- `unimidi` is optional and only needed for direct MIDI device output

## Installation

```bash
bundle add cyclotone
# or
gem install cyclotone
```

## Quick Start

```ruby
require "cyclotone"
include Cyclotone::DSL

setcps Rational(9, 16)

d1 s("bd sd:3 [~ bd] sd").gain(0.8)
d2 note("0 2 4 7").scale(:minor, root: "c4").s("superpiano")
d3 s("hh*8").every(4) { |pattern| pattern.fast(2) }.sometimes { |pattern| pattern.degrade }
```

## Local Usage

```bash
bundle exec bin/cyclotone
bundle exec ruby examples/midi_output.rb
bundle exec ruby examples/basic_beat.rb
```

`examples/midi_output.rb` writes `tmp/cyclotone_demo.mid`. OSC examples require a running SuperCollider/SuperDirt target and can use `CYCLOTONE_OSC_HOST` and `CYCLOTONE_OSC_PORT`.

## Development

```bash
bundle install
bundle exec rake
gem build cyclotone.gemspec
```

## Contributing

Bug reports and pull requests are welcome at https://github.com/ydah/cyclotone.

## License

Cyclotone is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
