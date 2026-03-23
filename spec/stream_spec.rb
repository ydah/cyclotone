# frozen_string_literal: true

RSpec.describe Cyclotone::Stream do
  subject(:stream) { described_class.instance }

  after do
    stream.hush
    stream.unsolo(:d1)
    stream.unmute(:d1)
  end

  it "stores patterns in preset slots" do
    stream.d(1, "bd sd")

    expect(stream.slot(:d1)).to be_a(Cyclotone::Pattern)
    expect(stream.slot(:d1).query_cycle(0).map(&:value)).to eq(%w[bd sd])
  end

  it "can mute and hush slots" do
    stream.d(1, "bd")
    stream.mute(:d1)
    stream.hush

    expect(stream.slot(:d1).query_cycle(0)).to eq([])
  end
end
