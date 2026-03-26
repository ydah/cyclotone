# frozen_string_literal: true

RSpec.describe Cyclotone::Stream do
  subject(:stream) { described_class.instance }

  after do
    stream.hush
    stream.instance_variable_get(:@slots).clear
    stream.instance_variable_get(:@soloed).clear
    stream.instance_variable_get(:@muted).clear
  end

  it "applies jump_in relative to the current scheduler cycle" do
    stream.reset_cycles
    stream.set_cycle(8)
    stream.p(:lead, Cyclotone::Controls.s("bd"))

    stream.jump_in(:lead, 2, Cyclotone::Controls.s("sd"))

    expect(stream.slot(:lead).query_cycle(8).map { |event| event.value[:s] }).to eq(["bd"])
    expect(stream.slot(:lead).query_cycle(9).map { |event| event.value[:s] }).to eq(["bd"])
    expect(stream.slot(:lead).query_cycle(10).map { |event| event.value[:s] }).to eq(["sd"])
  end

  it "uses clutch transitions to swap events instead of stacking both patterns" do
    stream.reset_cycles
    stream.set_cycle(0)
    stream.p(:lead, Cyclotone::Controls.s("bd"))

    stream.clutch_in(:lead, 2, Cyclotone::Controls.s("sd"))

    expect(stream.slot(:lead).query_cycle(0).map { |event| event.value[:s] }).to eq(["bd"])
    expect(stream.slot(:lead).query_cycle(2).map { |event| event.value[:s] }).to eq(["sd"])
  end

  it "interpolates numeric control values across a transition" do
    stream.reset_cycles
    stream.set_cycle(0)
    stream.p(:lead, Cyclotone::Controls.note(0).gain(1.0))

    stream.interpolate_in(:lead, 4, Cyclotone::Controls.note(4).gain(0.0))

    value = stream.slot(:lead).query_cycle(2).first.value

    expect(value[:note]).to be_within(0.001).of(2.0)
    expect(value[:gain]).to be_within(0.001).of(0.5)
  end

  it "fades active slots out over the requested number of cycles" do
    stream.reset_cycles
    stream.p(:lead, Cyclotone::Controls.s("bd").gain(1.0))

    stream.fade_out(2)

    first_gain = stream.slot(:lead).query_cycle(0).first.value[:gain]
    later_gain = stream.slot(:lead).query_cycle(3).first.value[:gain]

    expect(first_gain).to be > later_gain
    expect(later_gain).to eq(0.0)
  end
end
