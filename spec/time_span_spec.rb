# frozen_string_literal: true

RSpec.describe Cyclotone::TimeSpan do
  describe "#initialize" do
    it "coerces numeric values to Rational" do
      span = described_class.new(0, 1)

      expect(span.start).to eq(Rational(0))
      expect(span.stop).to eq(Rational(1))
    end

    it "rejects a stop before the start" do
      expect { described_class.new(2, 1) }.to raise_error(ArgumentError)
    end
  end

  describe "#duration" do
    it "returns the span length" do
      span = described_class.new(Rational(1, 4), Rational(3, 4))

      expect(span.duration).to eq(Rational(1, 2))
    end
  end

  describe "#midpoint" do
    it "returns the center of the span" do
      span = described_class.new(0, 1)

      expect(span.midpoint).to eq(Rational(1, 2))
    end
  end

  describe "#intersection" do
    it "returns the overlapping portion" do
      span = described_class.new(0, 1)
      other = described_class.new(Rational(1, 2), Rational(3, 2))

      expect(span.intersection(other)).to eq(described_class.new(Rational(1, 2), 1))
    end

    it "returns nil when spans do not overlap" do
      span = described_class.new(0, 1)
      other = described_class.new(1, 2)

      expect(span.intersection(other)).to be_nil
    end
  end

  describe "#includes?" do
    it "treats spans as half-open intervals" do
      span = described_class.new(0, 1)

      expect(span.includes?(0)).to be(true)
      expect(span.includes?(Rational(1, 2))).to be(true)
      expect(span.includes?(1)).to be(false)
    end
  end

  describe "#cycle_spans" do
    it "splits spans across cycle boundaries" do
      span = described_class.new(0, Rational(5, 2))

      expect(span.cycle_spans).to eq([
        described_class.new(0, 1),
        described_class.new(1, 2),
        described_class.new(2, Rational(5, 2))
      ])
    end

    it "returns an empty list for a zero-length span" do
      span = described_class.new(1, 1)

      expect(span.cycle_spans).to eq([])
    end
  end
end
