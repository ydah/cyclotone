# frozen_string_literal: true

RSpec.describe Cyclotone::MiniNotation::Compiler do
  it "compiles mini-notation into a pattern" do
    pattern = Cyclotone::Pattern.mn("bd [sd sd] hh cp")
    events = pattern.query_cycle(0)

    expect(events.map(&:value)).to eq(%w[bd sd sd hh cp])
  end

  it "compiles euclidean notation into gated events" do
    pattern = Cyclotone::Pattern.mn("bd(3,8)")

    expect(pattern.query_cycle(0).map(&:value)).to eq(%w[bd bd bd])
  end
end
