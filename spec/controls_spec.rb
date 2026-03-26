# frozen_string_literal: true

RSpec.describe Cyclotone::Controls do
  it "wraps parsed values into control hashes" do
    values = described_class.s("bd sd:3").query_cycle(0).map(&:value)

    expect(values).to eq([
      { s: "bd" },
      { s: "sd", n: 3 }
    ])
  end

  it "merges control patterns onto pattern values" do
    values = described_class.s("bd").gain(0.5).query_cycle(0).map(&:value)

    expect(values).to eq([{ s: "bd", gain: 0.5 }])
  end

  it "raises for unknown control names" do
    expect { described_class.control(:unknown, "bd") }.to raise_error(Cyclotone::InvalidControlError)
  end
end
