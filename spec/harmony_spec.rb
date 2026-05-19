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

  it "rejects unknown scales and invalid notes" do
    expect { described_class.scale(:missing, Cyclotone::Pattern.pure(0)) }.to raise_error(ArgumentError, /unknown scale/)
    expect { described_class.note_number("abc") }.to raise_error(ArgumentError, /invalid note/)
  end

  it "maps scale and transposition over note arrays" do
    pattern = Cyclotone::Pattern.pure({ note: [0, 2] }).scale(:major, root: "c4").up(12)

    expect(pattern.query_cycle(0).first.value[:note]).to eq([72, 76])
  end

  it "supports chord inversions, drop2, and octave spreading" do
    inverted = described_class.chord(:major, root: "c4", inversion: 1).query_cycle(0).first.value
    spread = described_class.chord(:major, root: "c4", octave_spread: 1).query_cycle(0).first.value
    drop2 = described_class.chord(:major7, root: "c4", drop2: true).query_cycle(0).first.value

    expect(inverted).to eq([64, 67, 72])
    expect(spread).to eq([60, 76, 91])
    expect(drop2).to include(55)
  end

  it "does not arpeggiate zero-duration events" do
    event = Cyclotone::Event.new(
      whole: Cyclotone::TimeSpan.new(0, 0),
      part: Cyclotone::TimeSpan.new(0, 0),
      value: [60, 64]
    )
    pattern = Cyclotone::Pattern.new { |_span| [event] }

    expect(described_class.arpeggiate(pattern).query_span([0, Cyclotone::Pattern.sample_epsilon])).to eq([])
  end
end
