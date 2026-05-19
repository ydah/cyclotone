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

  it "keeps generated representative spans well-formed" do
    random = Random.new(12_345)

    100.times do
      left = Rational(random.rand(0..64), 8)
      width = Rational(random.rand(0..32), 8)
      span = Cyclotone::TimeSpan.new(left, left + width)

      expect(span.duration).to be >= 0
      span.each_cycle_span do |cycle_span|
        expect(cycle_span.start).to be >= span.start
        expect(cycle_span.stop).to be <= span.stop
        expect(cycle_span.duration).to be >= 0
      end
    end
  end
end
