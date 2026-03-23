# frozen_string_literal: true

RSpec.describe Cyclotone::Harmony do
  it "maps degrees through scales" do
    values = Cyclotone::Pattern.fastcat([Cyclotone::Pattern.pure(0), Cyclotone::Pattern.pure(2)])
      .scale(:major, root: "c4")
      .query_cycle(0)
      .map(&:value)

    expect(values).to eq([60, 64])
  end

  it "builds chord note collections" do
    expect(described_class.chord(:minor, root: "c4").query_cycle(0).first.value).to eq([60, 63, 67])
  end

  it "arpeggiates chord values" do
    values = described_class.chord(:minor, root: "c4").arp(:down).query_cycle(0).map(&:value)

    expect(values).to eq([67, 63, 60])
  end
end
