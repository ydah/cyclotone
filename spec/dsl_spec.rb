# frozen_string_literal: true

RSpec.describe Cyclotone::DSL do
  let(:context) do
    Object.new.tap do |object|
      object.extend(described_class)
    end
  end

  it "exposes slot helpers and control factories" do
    context.d1(context.s("bd").gain(0.7))

    pattern = Cyclotone::Stream.instance.slot(:d1)
    expect(pattern.query_cycle(0).first.value).to eq({ s: "bd", gain: 0.7 })
  end

  it "exposes named-slot and transition helpers" do
    context.p(:lead, context.s("bd"))
    context.jump_in(:lead, 1, context.s("sd"))

    pattern = Cyclotone::Stream.instance.slot(:lead)
    expect(pattern).to be_a(Cyclotone::Pattern)
  end

  it "exposes trigger helpers" do
    stream = Cyclotone::Stream.instance

    allow(stream).to receive(:trigger)
    allow(stream).to receive(:qtrigger)
    allow(stream).to receive(:mtrigger)

    context.trigger
    context.qtrigger
    context.mtrigger(4)

    expect(stream).to have_received(:trigger)
    expect(stream).to have_received(:qtrigger)
    expect(stream).to have_received(:mtrigger).with(4)
  end
end
