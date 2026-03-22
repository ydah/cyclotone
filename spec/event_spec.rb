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
  end
end
