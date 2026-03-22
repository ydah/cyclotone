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
  end
end
