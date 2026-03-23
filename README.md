# Cyclotone

Cyclotone is a Ruby gem for pattern-based live coding. It uses exact rational time, composes immutable event patterns, parses a Tidal-style mini-notation, and ships with transforms, control patterns, oscillators, harmony helpers, a scheduler, and a DSL for slot-based performance.

The current implementation includes:

- `Cyclotone::TimeSpan`
- `Cyclotone::Event`
- `Cyclotone::Pattern`
- Mini-notation parsing and compilation with Euclidean rhythms
- Pattern transforms for time, concatenation, accumulation, alteration, condition, and sample operations
- Control factories, oscillators, harmony helpers, OSC/MIDI backends, scheduler, stream management, transitions, and a DSL/REPL entry point

## Installation

Add this line to your application's Gemfile:

```bash
bundle add cyclotone
```

Or install it directly:

```bash
gem install cyclotone
```

## Usage

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

Top-level DSL:

```ruby
require "cyclotone"
include Cyclotone::DSL

setcps Rational(9, 16)

d1 s("bd sd:3 [~ bd] sd").gain(0.8)
d2 note("0 2 4 7").scale(:minor, root: "c4").s("superpiano")
d3 s("hh*8").every(4) { |pattern| pattern.fast(2) }.sometimes { |pattern| pattern.degrade }
```

Open the REPL with:

```bash
bundle exec ruby exe/cyclotone
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
gem build cyclotone.gemspec
```

To install the gem locally for manual experiments:

```bash
bundle exec rake install
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/cyclotone.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
