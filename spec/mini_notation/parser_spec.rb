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
    expect(parser.parse("{bd sd, cp hh}%3")).to eq(
      Cyclotone::MiniNotation::AST::Polymetric.new(
        patterns: [
          Cyclotone::MiniNotation::AST::Sequence.new(
            elements: [
              Cyclotone::MiniNotation::AST::Atom.new(value: "bd"),
              Cyclotone::MiniNotation::AST::Atom.new(value: "sd")
            ]
          ),
          Cyclotone::MiniNotation::AST::Sequence.new(
            elements: [
              Cyclotone::MiniNotation::AST::Atom.new(value: "cp"),
              Cyclotone::MiniNotation::AST::Atom.new(value: "hh")
            ]
          )
        ],
        steps: 3
      )
    )
  end

  it "raises a parse error for invalid input" do
    expect { parser.parse("[bd sd") }.to raise_error(Cyclotone::ParseError)
  end

  it "parses quoted atoms with escapes" do
    ast = parser.parse('"kick/snare" "hat \"open\""')

    expect(ast).to eq(
      Cyclotone::MiniNotation::AST::Sequence.new(
        elements: [
          Cyclotone::MiniNotation::AST::Atom.new(value: "kick/snare"),
          Cyclotone::MiniNotation::AST::Atom.new(value: 'hat "open"')
        ]
      )
    )
  end

  it "rejects malformed numeric literals" do
    expect { parser.parse("1..2") }.to raise_error(Cyclotone::ParseError, /invalid number literal/)
    expect { parser.parse("1.2.3") }.to raise_error(Cyclotone::ParseError, /invalid number literal/)
  end

  it "rejects invalid suffix counts and probabilities" do
    expect { parser.parse("bd*0") }.to raise_error(Cyclotone::ParseError, /repeat count/)
    expect { parser.parse("bd!0") }.to raise_error(Cyclotone::ParseError, /replicate count/)
    expect { parser.parse("bd/0") }.to raise_error(Cyclotone::ParseError, /slow amount/)
    expect { parser.parse("bd@0") }.to raise_error(Cyclotone::ParseError, /elongate amount/)
    expect { parser.parse("bd?-1") }.to raise_error(Cyclotone::ParseError)
    expect { parser.parse("bd?2") }.to raise_error(Cyclotone::ParseError, /probability/)
    expect { parser.parse("bd:1.5") }.to raise_error(Cyclotone::ParseError, /sample number/)
  end

  it "rejects invalid euclidean and polymetric counts" do
    expect { parser.parse("bd(3,0)") }.to raise_error(Cyclotone::ParseError, /euclidean steps/)
    expect { parser.parse("{bd sd}%0") }.to raise_error(Cyclotone::ParseError, /polymetric steps/)
  end

  it "includes source context in parse errors" do
    expect { parser.parse("[bd sd") }.to raise_error(Cyclotone::ParseError) do |error|
      expect(error.message).to include("[bd sd")
      expect(error.message).to include("^")
    end
  end
end
