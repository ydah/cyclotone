# frozen_string_literal: true

RSpec.describe Cyclotone::Support::Deterministic do
  it "builds stable seeds from canonical values" do
    left = described_class.seed_for({ b: 2, a: [Rational(1, 3), "x"] })
    right = described_class.seed_for({ a: [Rational(1, 3), "x"], b: 2 })

    expect(left).to eq(right)
    expect(left).to eq(described_class.seed_for({ b: 2, a: [Rational(1, 3), "x"] }))
  end
end
