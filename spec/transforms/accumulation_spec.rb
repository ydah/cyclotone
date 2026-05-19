# frozen_string_literal: true

RSpec.describe "accumulation transforms" do
  let(:base) { Cyclotone::Controls.s("bd sd") }

  it "overlays patterns in the same cycle" do
    values = base.overlay(Cyclotone::Controls.s("hh")).query_cycle(0).map(&:value)

    expect(values.map { |value| value[:s] }).to include("bd", "sd", "hh")
  end

  it "splits jux output across the stereo field" do
    values = base.jux { |pattern| pattern.fast(2) }.query_cycle(0).map(&:value)

    expect(values.map { |value| value[:pan] }).to include(0.0, 1.0)
  end

  it "alternates weave controls across fastcat subdivisions" do
    values = base.weave(2, base, [Cyclotone::Controls.pan(0), Cyclotone::Controls.pan(1)]).query_cycle(0).map(&:value)

    expect(values.map { |value| value[:pan] }).to eq([0, 0, 1, 1])
  end

  it "validates accumulation transform arguments" do
    expect { base.superimpose }.to raise_error(ArgumentError, /block/)
    expect { base.layer([]) }.to raise_error(ArgumentError, /functions/)
    expect { base.jux_by(1) }.to raise_error(ArgumentError, /block/)
    expect { base.weave_with(0, base, [->(pattern) { pattern }]) }.to raise_error(ArgumentError, /weave/)
    expect { base.weave_with(1, base, []) }.to raise_error(ArgumentError, /functions/)
  end

  it "clamps jux pan values into the stereo range" do
    pans = base.jux_by(3) { |pattern| pattern }.query_cycle(0).map { |event| event.value[:pan] }.uniq

    expect(pans).to eq([0.0, 1.0])
  end
end
