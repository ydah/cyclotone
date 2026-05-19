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

  it "smooths discrete patterns with linear interpolation" do
    pattern = Cyclotone::Pattern.fastcat([Cyclotone::Pattern.pure(0), Cyclotone::Pattern.pure(1)])
    value = described_class.smooth(pattern).query_point(Rational(1, 2))

    expect(value).to be_within(0.001).of(0.5)
  end

  it "supports custom smoothing for non-numeric values" do
    pattern = Cyclotone::Pattern.fastcat([
      Cyclotone::Pattern.pure("closed"),
      Cyclotone::Pattern.pure("open")
    ])
    smoothed = described_class.smooth(pattern) do |left, right, amount|
      "#{left}:#{right}:#{amount.round(2)}"
    end

    expect(smoothed.query_point(Rational(1, 2))).to eq("closed:open:0.5")
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

  it "supports oscillator frequency, phase, and bipolar output" do
    value = described_class.sine(freq: 2, phase: Rational(1, 4), bipolar: true).query_point(0)

    expect(value).to be_within(0.001).of(1.0)
  end

  it "validates random oscillator bounds" do
    expect { described_class.rand(steps: 0) }.to raise_error(ArgumentError, /steps/)
    expect { described_class.irand(0) }.to raise_error(ArgumentError, /maximum/)
  end

  it "normalizes range inputs with clamp wrap and fold modes" do
    high = Cyclotone::Pattern.pure(1.5)

    expect(described_class.range(0, 10, high, mode: :clamp).query_cycle(0).first.value).to eq(10.0)
    expect(described_class.range(0, 10, high, mode: :wrap).query_cycle(0).first.value).to eq(5.0)
    expect(described_class.range(0, 10, high, mode: :fold).query_cycle(0).first.value).to eq(5.0)
  end

  it "provides noise, sample-and-hold, and brownian helpers" do
    held = described_class.sample_and_hold(Cyclotone::Pattern.fastcat([0, 1]), steps: 2)

    expect(described_class.noise.query_cycle(0).first.value).to be_between(0.0, 1.0)
    expect(held.query_point(Rational(1, 4))).to eq(0)
    expect(described_class.brownian.query_cycle(0).first.value).to be_between(0.0, 1.0)
  end

  it "caches brownian random walk steps across queries" do
    allow(Cyclotone::Support::Deterministic).to receive(:float).and_call_original
    pattern = described_class.brownian

    pattern.query_point(8)
    expect(Cyclotone::Support::Deterministic).to have_received(:float).exactly(9).times

    pattern.query_point(8)
    expect(Cyclotone::Support::Deterministic).to have_received(:float).exactly(9).times

    pattern.query_point(10)
    expect(Cyclotone::Support::Deterministic).to have_received(:float).exactly(11).times
  end
end
