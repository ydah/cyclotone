# frozen_string_literal: true

RSpec.describe Cyclotone::Event do
  let(:whole) { Cyclotone::TimeSpan.new(0, 1) }
  let(:part) { Cyclotone::TimeSpan.new(0, Rational(1, 2)) }

  describe "#triggered?" do
    it "is true when the onset is inside the queried part" do
      event = described_class.new(whole: whole, part: whole, value: "bd")

      expect(event.triggered?).to be(true)
    end

    it "is false when the onset is outside the queried part" do
      event = described_class.new(whole: whole, part: part, value: "bd")

      expect(event.triggered?).to be(true)
      expect(described_class.new(whole: whole, part: Cyclotone::TimeSpan.new(Rational(1, 2), 1), value: "bd").triggered?).to be(false)
    end

    it "is false when the event has no whole span" do
      event = described_class.new(whole: nil, part: part, value: 12)

      expect(event.triggered?).to be(false)
    end
  end

  describe "#duration" do
    it "returns the whole span duration when present" do
      event = described_class.new(whole: whole, part: part, value: "bd")

      expect(event.duration).to eq(1)
    end
  end

  describe "#with_value" do
    it "returns a new event with the updated value" do
      event = described_class.new(whole: whole, part: part, value: "bd")

      updated = event.with_value("sd")

      expect(updated.value).to eq("sd")
      expect(updated.whole).to eq(event.whole)
      expect(updated.part).to eq(event.part)
      expect(event.value).to eq("bd")
    end

    it "deep-freezes mutable values" do
      event = described_class.new(whole: whole, part: part, value: { notes: [60, 64] })

      expect(event.value).to be_frozen
      expect(event.value[:notes]).to be_frozen
      expect { event.value[:notes] << 67 }.to raise_error(FrozenError)
    end
  end

  describe "#with_span" do
    it "returns a new event with updated spans" do
      event = described_class.new(whole: whole, part: part, value: "bd")
      new_whole = Cyclotone::TimeSpan.new(1, 2)
      new_part = Cyclotone::TimeSpan.new(1, Rational(3, 2))

      updated = event.with_span(new_whole: new_whole, new_part: new_part)

      expect(updated.whole).to eq(new_whole)
      expect(updated.part).to eq(new_part)
      expect(updated.value).to eq("bd")
    end

    it "accepts concise span keywords" do
      event = described_class.new(whole: whole, part: part, value: "bd")
      new_part = Cyclotone::TimeSpan.new(1, 2)

      expect(event.with_span(part: new_part).part).to eq(new_part)
    end
  end

  describe "#initialize" do
    it "requires a part span" do
      expect { described_class.new(whole: whole, part: nil, value: "bd") }.to raise_error(ArgumentError, /part/)
    end
  end

  describe "#to_h" do
    it "exposes event fields for introspection" do
      event = described_class.new(whole: whole, part: part, value: "bd")

      expect(event.to_h).to eq(whole: whole, part: part, value: "bd")
    end
  end
end
