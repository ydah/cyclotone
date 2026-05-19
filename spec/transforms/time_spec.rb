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

  it "returns to the source ordering across a palindrome pair" do
    transformed = pattern.palindrome

    expect(transformed.query_cycle(0).map(&:value)).to eq(%w[sd bd])
    expect(transformed.query_cycle(1).map(&:value)).to eq(%w[bd sd])
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

  it "defaults nil speed while hurrying hash values" do
    hurried = Cyclotone::Pattern.pure({ s: "bd", speed: nil }).hurry(2)

    expect(hurried.query_cycle(0).first.value[:speed]).to eq(2.0)
  end

  it "rejects non-positive time scaling amounts" do
    expect { pattern.fast(0) }.to raise_error(ArgumentError, /fast amount/)
    expect { pattern.slow(-1) }.to raise_error(ArgumentError, /slow amount/)
  end

  it "requires blocks for scoped time transforms" do
    expect { pattern.off(Rational(1, 8)) }.to raise_error(ArgumentError, /block/)
    expect { pattern.inside(2) }.to raise_error(ArgumentError, /block/)
    expect { pattern.outside(2) }.to raise_error(ArgumentError, /block/)
  end

  it "rejects invalid swing divisions" do
    expect { pattern.swing(0.1, 0) }.to raise_error(ArgumentError, /division/)
  end

  it "clips swung events to the current cycle" do
    swung = Cyclotone::Pattern.mn("bd bd").swing(1, 2)

    expect(swung.query_cycle(0).all? { |event| event.part.start >= 0 && event.part.stop <= 1 }).to be(true)
  end
end
