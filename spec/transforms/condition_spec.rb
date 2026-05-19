# frozen_string_literal: true

RSpec.describe "condition transforms" do
  let(:base) { Cyclotone::Pattern.mn("bd sd") }

  it "applies when_mod after the configured threshold" do
    transformed = base.when_mod(3, 1) { |pattern| pattern.rev }

    expect(transformed.query_cycle(0).map(&:value)).to eq(%w[bd sd])
    expect(transformed.query_cycle(1).map(&:value)).to eq(%w[sd bd])
  end

  it "applies fix only where the control pattern is truthy" do
    values = base.fix(Cyclotone::Pattern.mn("1 ~")) { |pattern| pattern.fmap(&:upcase) }.query_cycle(0).map(&:value)

    expect(values).to eq(["BD", "sd"])
  end

  it "uses contrast to branch between transformed and original output" do
    values = base.contrast(
      proc { |pattern| pattern.fmap(&:upcase) },
      proc { |pattern| pattern },
      Cyclotone::Pattern.mn("1 ~")
    ).query_cycle(0).map(&:value)

    expect(values).to eq(["BD", "sd"])
  end

  it "filters events with mask" do
    values = base.mask(Cyclotone::Pattern.mn("1 ~")).query_cycle(0).map(&:value)

    expect(values).to eq(["bd"])
  end

  it "supports continuous boolean masks" do
    mask = Cyclotone::Pattern.continuous { |time| time < Rational(1, 2) }

    expect(base.mask(mask).query_cycle(0).map(&:value)).to eq(["bd"])
  end

  it "keeps source events when fix target is silent" do
    fixed = base.fix(Cyclotone::Pattern.pure(true)) { Cyclotone::Pattern.silence }

    expect(fixed.query_cycle(0).map(&:value)).to eq(%w[bd sd])
  end

  it "treats zero as false in struct gates" do
    structured = Cyclotone::Pattern.pure("bd").struct(Cyclotone::Pattern.mn("1 0 1 0"))

    expect(structured.query_cycle(0).map(&:value)).to eq(%w[bd bd])
  end

  it "validates condition transform arguments" do
    expect { base.when_mod(0, 0) { |pattern| pattern } }.to raise_error(ArgumentError, /period/)
    expect { base.when_mod(2, 0) }.to raise_error(ArgumentError, /block/)
    expect { base.fix(Cyclotone::Pattern.pure(true)) }.to raise_error(ArgumentError, /block/)
    expect { base.unfix(Cyclotone::Pattern.pure(true)) }.to raise_error(ArgumentError, /block/)
    expect { base.contrast(nil, proc { |pattern| pattern }, Cyclotone::Pattern.pure(true)) }.to raise_error(ArgumentError, /true function/)
  end
end
