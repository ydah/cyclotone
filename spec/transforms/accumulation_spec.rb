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
end
