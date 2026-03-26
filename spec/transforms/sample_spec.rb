# frozen_string_literal: true

RSpec.describe "sample transforms" do
  let(:base) { Cyclotone::Controls.s("bd") }

  it "chops a sample into equal begin/end segments" do
    values = base.chop(2).query_cycle(0).map(&:value)

    expect(values).to eq([
      { s: "bd", begin: 0.0, end: 0.5 },
      { s: "bd", begin: 0.5, end: 1.0 }
    ])
  end

  it "adds slice speed compensation with splice" do
    value = base.splice(4, Cyclotone::Pattern.pure(2)).query_cycle(0).first.value

    expect(value).to include(s: "bd", begin: 0.5, end: 0.75, speed: 4)
  end

  it "fits playback speed with loop_at" do
    value = base.loop_at(2).query_cycle(0).first.value

    expect(value).to include(s: "bd", speed: 0.5)
  end

  it "segments continuous patterns into discrete events" do
    values = Cyclotone::Oscillators.saw.segment(4).query_cycle(0).map(&:value)

    expect(values.length).to eq(4)
    expect(values.first).to be < values.last
  end
end
