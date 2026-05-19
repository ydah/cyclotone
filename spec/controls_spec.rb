# frozen_string_literal: true

RSpec.describe Cyclotone::Controls do
  it "wraps parsed values into control hashes" do
    values = described_class.s("bd sd:3").query_cycle(0).map(&:value)

    expect(values).to eq([
      { s: "bd" },
      { s: "sd", n: 3 }
    ])
  end

  it "uses explicit mini-notation coercion for string controls" do
    values = described_class.gain("0.25 0.75").query_cycle(0).map(&:value)

    expect(values).to eq([{ gain: 0.25 }, { gain: 0.75 }])
  end

  it "merges control patterns onto pattern values" do
    values = described_class.s("bd").gain(0.5).query_cycle(0).map(&:value)

    expect(values).to eq([{ s: "bd", gain: 0.5 }])
  end

  it "raises for unknown control names" do
    expect { described_class.control(:unknown, "bd") }.to raise_error(Cyclotone::InvalidControlError)
  end

  it "preserves falsey values when wrapping hashes" do
    value = described_class.gain({ value: 0 }).query_cycle(0).first.value

    expect(value[:gain]).to eq(0)
  end

  it "validates ranged control values" do
    expect { described_class.pan(1.5).query_cycle(0) }.to raise_error(Cyclotone::InvalidControlError, /pan/)
    expect { described_class.gain(-0.1).query_cycle(0) }.to raise_error(Cyclotone::InvalidControlError, /gain/)
    expect { described_class.channel(16).query_cycle(0) }.to raise_error(Cyclotone::InvalidControlError, /channel/)
    expect { described_class.cc({ 128 => 1 }).query_cycle(0) }.to raise_error(Cyclotone::InvalidControlError, /controllers/)
  end

  it "allows fractional note controls for non-midi or explicitly quantized midi use" do
    value = described_class.note(60.5).query_cycle(0).first.value

    expect(value[:note]).to eq(60.5)
  end
end
