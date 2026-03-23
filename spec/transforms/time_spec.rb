# frozen_string_literal: true

RSpec.describe "time and alteration transforms" do
  let(:pattern) { Cyclotone::Pattern.mn("bd sd") }

  it "repeats events with fast" do
    expect(pattern.fast(2).query_cycle(0).map(&:value)).to eq(%w[bd sd bd sd])
  end

  it "slows events across cycles" do
    expect(pattern.slow(2).query_cycle(0).map(&:value)).to eq(["bd"])
    expect(pattern.slow(2).query_cycle(1).map(&:value)).to eq(["sd"])
  end

  it "reverses a cycle" do
    expect(pattern.rev.query_cycle(0).map(&:value)).to eq(%w[sd bd])
  end

  it "applies every on matching cycles only" do
    transformed = pattern.every(2) { |value| value.rev }

    expect(transformed.query_cycle(0).map(&:value)).to eq(%w[sd bd])
    expect(transformed.query_cycle(1).map(&:value)).to eq(%w[bd sd])
  end

  it "degrades all events at probability 1.0" do
    expect(pattern.degrade_by(1.0).query_cycle(0)).to eq([])
  end

  it "uses a boolean pattern as structure" do
    structured = Cyclotone::Pattern.pure("bd").struct(Cyclotone::Pattern.mn("1 ~ 1 ~"))

    expect(structured.query_cycle(0).map(&:value)).to eq(%w[bd bd])
  end
end
