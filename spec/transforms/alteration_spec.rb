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

  it "validates alteration transform arguments" do
    expect { base.every(0) { |pattern| pattern.rev } }.to raise_error(ArgumentError, /period/)
    expect { base.sometimes_by(1.1) { |pattern| pattern.rev } }.to raise_error(ArgumentError, /probability/)
    expect { base.degrade_by(-0.1) }.to raise_error(ArgumentError, /probability/)
    expect { base.chunk(0) { |pattern| pattern.rev } }.to raise_error(ArgumentError, /count/)
    expect { base.zoom(Rational(1, 2), Rational(1, 2)) }.to raise_error(ArgumentError, /zoom/)
    expect { base.trunc(Rational(3, 2)) }.to raise_error(ArgumentError, /trunc/)
    expect { base.spread(->(pattern, _factor) { pattern }, []) }.to raise_error(ArgumentError, /values/)
  end
end
