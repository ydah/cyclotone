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
end
