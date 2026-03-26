# frozen_string_literal: true

RSpec.describe Cyclotone::State do
  subject(:state) { described_class.instance }

  it "stores and retrieves typed values" do
    state.set_f(:swing, 0.75)
    state.set_i(:step, 12.9)
    state.set_s(:mode, :minor)

    expect(state.get_f(:swing)).to eq(0.75)
    expect(state.get_i(:step)).to eq(12)
    expect(state.get_s(:mode)).to eq("minor")
  end
end
