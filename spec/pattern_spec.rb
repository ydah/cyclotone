# frozen_string_literal: true

RSpec.describe Cyclotone::Pattern do
  describe ".pure" do
    it "returns one event per queried cycle segment" do
      pattern = described_class.pure("bd")
      events = pattern.query_span(Cyclotone::TimeSpan.new(Rational(1, 2), Rational(3, 2)))

      expect(events.map(&:value)).to eq(%w[bd bd])
      expect(events.map(&:whole)).to eq([
        Cyclotone::TimeSpan.new(0, 1),
        Cyclotone::TimeSpan.new(1, 2)
      ])
      expect(events.map(&:part)).to eq([
        Cyclotone::TimeSpan.new(Rational(1, 2), 1),
        Cyclotone::TimeSpan.new(1, Rational(3, 2))
      ])
    end
  end

  describe ".atom_at" do
    it "emits an onset-only event at a cycle-relative offset" do
      pattern = described_class.atom_at("bd", at: Rational(1, 4))
      events = pattern.query_cycle(0)

      expect(events.map(&:onset)).to eq([Rational(1, 4)])
      expect(events.map(&:value)).to eq(["bd"])
    end
  end

  describe ".silence" do
    it "returns no events" do
      pattern = described_class.silence

      expect(pattern.query_cycle(0)).to eq([])
    end
  end

  describe "#fmap" do
    it "transforms event values without changing structure" do
      pattern = described_class.pure("bd").fmap { |value| value.upcase }

      events = pattern.query_cycle(0)

      expect(events.map(&:value)).to eq(["BD"])
      expect(events.first.whole).to eq(Cyclotone::TimeSpan.new(0, 1))
    end
  end

  describe "#query_span" do
    it "accepts start and stop pairs" do
      pattern = described_class.pure("bd")

      expect(pattern.query_span([0, 1]).map(&:value)).to eq(["bd"])
    end
  end

  describe "#query_points" do
    it "returns all overlapping values at a time" do
      pattern = described_class.stack([described_class.pure("bd"), described_class.pure("hh")])

      expect(pattern.query_points(Rational(1, 2))).to eq(%w[bd hh])
    end
  end

  describe ".ensure_pattern" do
    it "keeps string values literal by default" do
      pattern = described_class.ensure_pattern("bd sd")

      expect(pattern.query_cycle(0).map(&:value)).to eq(["bd sd"])
    end

    it "can treat strings as mini-notation explicitly" do
      pattern = described_class.ensure_pattern("bd sd", strings: :mini_notation)

      expect(pattern.query_cycle(0).map(&:value)).to eq(%w[bd sd])
    end
  end

  describe ".to_rational" do
    it "wraps invalid rational input in a Cyclotone error" do
      expect { described_class.to_rational("abc") }.to raise_error(Cyclotone::InvalidRationalError, /invalid rational/)
    end
  end

  describe ".fastcat" do
    it "concatenates patterns evenly inside a cycle" do
      pattern = described_class.fastcat([
        described_class.pure("bd"),
        described_class.pure("sd")
      ])

      events = pattern.query_cycle(0)

      expect(events).to eq([
        Cyclotone::Event.new(
          whole: Cyclotone::TimeSpan.new(0, Rational(1, 2)),
          part: Cyclotone::TimeSpan.new(0, Rational(1, 2)),
          value: "bd"
        ),
        Cyclotone::Event.new(
          whole: Cyclotone::TimeSpan.new(Rational(1, 2), 1),
          part: Cyclotone::TimeSpan.new(Rational(1, 2), 1),
          value: "sd"
        )
      ])
    end

    it "rejects empty pattern lists" do
      expect { described_class.fastcat([]) }.to raise_error(ArgumentError, /timecat requires patterns/)
    end
  end

  describe ".timecat" do
    it "rejects non-positive weights" do
      expect { described_class.timecat([[0, described_class.pure("bd")]]) }.to raise_error(ArgumentError, /weights/)
      expect { described_class.timecat([[-1, described_class.pure("bd")]]) }.to raise_error(ArgumentError, /weights/)
    end
  end

  describe ".cat" do
    it "rotates one pattern per cycle" do
      pattern = described_class.cat(%w[bd sd])

      expect(pattern.query_cycle(0).map(&:value)).to eq(["bd"])
      expect(pattern.query_cycle(1).map(&:value)).to eq(["sd"])
      expect(pattern.query_cycle(2).map(&:value)).to eq(["bd"])
    end
  end

  describe ".randcat" do
    it "rejects empty pattern lists" do
      expect { described_class.randcat([]).query_cycle(0) }.to raise_error(ArgumentError, /randcat/)
    end

    it "uses namespace to de-correlate random choices" do
      left = described_class.randcat(%w[bd sd], namespace: :left).query_cycle(1).map(&:value)
      left_again = described_class.randcat(%w[bd sd], namespace: :left).query_cycle(1).map(&:value)
      right = described_class.randcat(%w[bd sd], namespace: :right).query_cycle(1).map(&:value)

      expect(left_again).to eq(left)
      expect([left, right].flatten).to all(satisfy { |value| %w[bd sd].include?(value) })
    end
  end

  describe "#merge" do
    it "ignores nil right-side hash values" do
      pattern = described_class.pure({ gain: 0.8, pan: 0.2 }).merge(described_class.pure({ gain: nil, speed: 2 }))

      expect(pattern.query_cycle(0).first.value).to eq({ gain: 0.8, pan: 0.2, speed: 2 })
    end

    it "can prefer left-side values" do
      pattern = described_class.pure({ gain: 0.8 }).merge_left(described_class.pure({ gain: 0.2, pan: 1 }))

      expect(pattern.query_cycle(0).first.value).to eq({ gain: 0.8, pan: 1 })
    end

    it "can merge nested hash values" do
      pattern = described_class.pure({ fx: { room: 0.1, size: 0.3 } }).merge_deep(
        described_class.pure({ fx: { room: nil, dry: 0.8 } })
      )

      expect(pattern.query_cycle(0).first.value).to eq({ fx: { room: 0.1, size: 0.3, dry: 0.8 } })
    end
  end

  describe "#combine_left" do
    it "samples continuous patterns on the left event onset" do
      control = described_class.continuous(sample: :begin) { |time| time }
      pattern = described_class.fastcat([described_class.pure("bd"), described_class.pure("sd")])
        .combine_left(control) { |value, control_value| [value, control_value] }

      expect(pattern.query_cycle(0).map(&:value)).to eq([["bd", Rational(0)], ["sd", Rational(1, 2)]])
    end
  end

  describe "#combine_both" do
    it "only combines overlapping events after pruning earlier candidates" do
      left = described_class.fastcat([described_class.pure("bd"), described_class.pure("sd")])
      right = described_class.atom_at("late", at: Rational(3, 4), duration: Rational(1, 8))

      values = left.combine_both(right) { |left_value, right_value| [left_value, right_value] }.query_cycle(0).map(&:value)

      expect(values).to eq([["sd", "late"]])
    end
  end

  describe ".stack" do
    it "overlays all events in the same query span" do
      pattern = described_class.stack([
        described_class.pure("bd"),
        described_class.pure("hh")
      ])

      events = pattern.query_cycle(0)

      expect(events.map(&:value)).to eq(%w[bd hh])
      expect(events.map(&:whole)).to eq([
        Cyclotone::TimeSpan.new(0, 1),
        Cyclotone::TimeSpan.new(0, 1)
      ])
    end

    it "can opt into silence for empty stacks" do
      expect(described_class.stack([], empty: :silence).query_cycle(0)).to eq([])
    end
  end

  describe ".continuous" do
    it "can sample at the beginning of a span" do
      pattern = described_class.continuous(sample: :begin) { |time| time }

      expect(pattern.query_span([Rational(1, 4), Rational(1, 2)]).first.value).to eq(Rational(1, 4))
    end
  end

  describe ".try_mn" do
    it "returns nil instead of raising for invalid mini-notation" do
      expect(described_class.try_mn("[bd")).to be_nil
    end
  end
end
