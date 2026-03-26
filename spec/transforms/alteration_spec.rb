# frozen_string_literal: true

RSpec.describe "alteration transforms" do
  let(:base) { Cyclotone::Pattern.mn("bd sd hh cp") }

  it "rotates the transformed chunk across cycles" do
    transformed = base.chunk(2) { |pattern| pattern.rev }

    expect(transformed.query_cycle(0).map(&:value)).to eq(%w[sd bd hh cp])
    expect(transformed.query_cycle(1).map(&:value)).to eq(%w[bd sd cp hh])
  end

  it "clips a pattern with trunc" do
    values = base.trunc(Rational(1, 2)).query_cycle(0).map(&:value)

    expect(values).to eq(%w[bd sd])
  end

  it "spreads a transform over successive cycles" do
    transformed = base.spread(->(pattern, factor) { pattern.fast(factor) }, [1, 2])

    expect(transformed.query_cycle(0).map(&:value)).to eq(%w[bd sd hh cp])
    expect(transformed.query_cycle(1).map(&:value)).to eq(%w[bd sd hh cp bd sd hh cp])
  end
end
