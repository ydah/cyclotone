# Cyclotone

Cyclotone is a Ruby gem for pattern-based live coding. It starts with an exact rational-time core so rhythmic structure can be expressed without floating-point drift, and it exposes immutable event and pattern primitives that can be composed into larger sequencing tools.

The current implementation covers the phase-1 core from `.idea/01_technical_specification.md`:

- `Cyclotone::TimeSpan`
- `Cyclotone::Event`
- `Cyclotone::Pattern`
- `Pattern.pure`, `Pattern.silence`, `Pattern.fastcat`, `Pattern.stack`, and `#fmap`

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

beat = Cyclotone::Pattern.fastcat([
  Cyclotone::Pattern.pure("bd"),
  Cyclotone::Pattern.pure("sd")
])

events = beat.query_cycle(0)

events.map { |event| [event.whole.to_s, event.part.to_s, event.value] }
# => [["[0, 1/2)", "[0, 1/2)", "bd"], ["[1/2, 1)", "[1/2, 1)", "sd"]]
```

Transform values while keeping structure:

```ruby
accented = beat.fmap { |value| { sound: value, gain: 0.9 } }
accented.query_cycle(0).map(&:value)
# => [{ sound: "bd", gain: 0.9 }, { sound: "sd", gain: 0.9 }]
```

## Development

```bash
bundle install
bundle exec rspec
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
