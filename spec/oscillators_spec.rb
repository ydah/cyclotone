# frozen_string_literal: true

RSpec.describe Cyclotone::Oscillators do
  it "builds continuous oscillator patterns" do
    expect(described_class.saw.query_cycle(0).first.value).to be_within(0.001).of(0.5)
    expect(described_class.square.query_cycle(0).first.value).to eq(1.0)
  end

  it "scales oscillator output ranges" do
    value = described_class.range(10, 20, described_class.saw).query_cycle(0).first.value

    expect(value).to be_within(0.01).of(15.0)
  end

  it "segments continuous patterns into discrete steps" do
    values = described_class.saw.segment(4).query_cycle(0).map(&:value)

    expect(values.length).to eq(4)
    expect(values.first).to be < values.last
  end

  it "creates deterministic integer random values" do
    value = described_class.irand(4).query_cycle(0).first.value

    expect(value).to be_between(0, 3)
  end
end
