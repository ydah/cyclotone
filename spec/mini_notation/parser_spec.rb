# frozen_string_literal: true

RSpec.describe Cyclotone::MiniNotation::Parser do
  subject(:parser) { described_class.new }

  it "parses basic sequences" do
    ast = parser.parse("bd sd hh cp")

    expect(ast).to eq(
      Cyclotone::MiniNotation::AST::Sequence.new(
        elements: [
          Cyclotone::MiniNotation::AST::Atom.new(value: "bd"),
          Cyclotone::MiniNotation::AST::Atom.new(value: "sd"),
          Cyclotone::MiniNotation::AST::Atom.new(value: "hh"),
          Cyclotone::MiniNotation::AST::Atom.new(value: "cp")
        ]
      )
    )
  end

  it "parses rests and groups" do
    ast = parser.parse("[bd sd] ~")

    expect(ast).to eq(
      Cyclotone::MiniNotation::AST::Sequence.new(
        elements: [
          Cyclotone::MiniNotation::AST::Sequence.new(
            elements: [
              Cyclotone::MiniNotation::AST::Atom.new(value: "bd"),
              Cyclotone::MiniNotation::AST::Atom.new(value: "sd")
            ]
          ),
          Cyclotone::MiniNotation::AST::Rest.new
        ]
      )
    )
  end

  it "parses stack, repeat, slow, alternating, degrade, sample, euclidean, and polymetric forms" do
    expect(parser.parse("[bd sd, hh hh]")).to be_a(Cyclotone::MiniNotation::AST::Stack)
    expect(parser.parse("bd*3")).to eq(
      Cyclotone::MiniNotation::AST::Repeat.new(
        pattern: Cyclotone::MiniNotation::AST::Atom.new(value: "bd"),
        count: 3
      )
    )
    expect(parser.parse("bd/2")).to eq(
      Cyclotone::MiniNotation::AST::Slow.new(
        pattern: Cyclotone::MiniNotation::AST::Atom.new(value: "bd"),
        amount: 2
      )
    )
    expect(parser.parse("<bd sd hh>")).to be_a(Cyclotone::MiniNotation::AST::Alternating)
    expect(parser.parse("bd?0.8")).to eq(
      Cyclotone::MiniNotation::AST::Degrade.new(
        pattern: Cyclotone::MiniNotation::AST::Atom.new(value: "bd"),
        probability: 0.8
      )
    )
    expect(parser.parse("bd:3")).to eq(Cyclotone::MiniNotation::AST::Atom.new(value: "bd", sample: 3))
    expect(parser.parse("bd(3,8,2)")).to eq(
      Cyclotone::MiniNotation::AST::Euclidean.new(
        pattern: Cyclotone::MiniNotation::AST::Atom.new(value: "bd"),
        pulses: 3,
        steps: 8,
        rotation: 2
      )
    )
    expect(parser.parse("{bd sd, cp hh}")).to be_a(Cyclotone::MiniNotation::AST::Polymetric)
  end

  it "raises a parse error for invalid input" do
    expect { parser.parse("[bd sd") }.to raise_error(Cyclotone::ParseError)
  end
end
