# frozen_string_literal: true

RSpec.describe "core pattern properties" do
  it "keeps intersections commutative for representative spans" do
    spans = [
      Cyclotone::TimeSpan.new(0, 1),
      Cyclotone::TimeSpan.new(Rational(1, 3), Rational(4, 3)),
      Cyclotone::TimeSpan.new(1, 2),
      Cyclotone::TimeSpan.new(Rational(5, 4), Rational(9, 4))
    ]

    spans.product(spans).each do |left, right|
      expect(left.intersection(right)).to eq(right.intersection(left))
    end
  end

  it "keeps queried event parts inside the requested span" do
    span = Cyclotone::TimeSpan.new(Rational(1, 8), Rational(15, 8))
    patterns = [
      Cyclotone::Pattern.mn("bd sd hh cp"),
      Cyclotone::Pattern.mn("[bd sd, hh hh]").fast(2),
      Cyclotone::Pattern.mn("bd(3,8)").rev,
      Cyclotone::Oscillators.saw.segment(8)
    ]

    patterns.each do |pattern|
      pattern.query_span(span).each do |event|
        expect(event.part.start).to be >= span.start
        expect(event.part.stop).to be <= span.stop
      end
    end
  end

  it "returns to the original cycle ordering after two reversals" do
    pattern = Cyclotone::Pattern.mn("bd sd hh cp")

    expect(pattern.rev.rev.query_cycle(0).map(&:value)).to eq(pattern.query_cycle(0).map(&:value))
  end
end
