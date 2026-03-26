# frozen_string_literal: true

RSpec.describe Cyclotone::Stream do
  subject(:stream) { described_class.instance }

  after do
    stream.hush
    stream.instance_variable_get(:@slots).clear
    stream.instance_variable_get(:@soloed).clear
    stream.instance_variable_get(:@muted).clear
  end

  it "stores patterns in preset slots" do
    stream.d(1, "bd sd")

    expect(stream.slot(:d1)).to be_a(Cyclotone::Pattern)
    expect(stream.slot(:d1).query_cycle(0).map(&:value)).to eq(%w[bd sd])
  end

  it "supports named slots for assignment and muting" do
    stream.p(:lead, "bd")

    expect(stream.slot(:lead).query_cycle(0).map(&:value)).to eq(["bd"])

    stream.mute(:lead)

    expect(stream.send(:active_slots)).not_to have_key(:lead)

    stream.unmute(:lead)

    expect(stream.send(:active_slots)).to have_key(:lead)
  end

  it "can solo and unsolo a slot" do
    stream.d(1, "bd")
    stream.d(2, "sd")

    stream.solo(:d1)

    expect(stream.send(:active_slots).keys).to eq([:d1])

    stream.unsolo(:d1)

    expect(stream.send(:active_slots).keys).to contain_exactly(:d1, :d2)
  end

  it "can mute and hush slots" do
    stream.d(1, "bd")
    stream.mute(:d1)
    stream.hush

    expect(stream.slot(:d1).query_cycle(0)).to eq([])
  end

  it "supports trigger quantization helpers" do
    scheduler = stream.scheduler

    allow(scheduler).to receive(:current_cycle).and_return(1.25, 1.25, 1.25)
    allow(scheduler).to receive(:cps).and_return(2.0)
    allow(scheduler).to receive(:interval).and_return(0.5)
    allow(stream).to receive(:sleep)

    stream.trigger
    stream.qtrigger
    stream.mtrigger(4)

    expect(stream).to have_received(:sleep).with(0.5)
    expect(stream).to have_received(:sleep).with(0.375)
    expect(stream).to have_received(:sleep).with(1.375)
  end
end
