# frozen_string_literal: true

RSpec.describe Cyclotone::MiniNotation::AST do
  it "deep-freezes array fields" do
    sequence = described_class::Sequence.new(
      elements: [described_class::Atom.new(value: "bd")]
    )

    expect(sequence.elements).to be_frozen
    expect(sequence.elements.first).to be_frozen
    expect { sequence.elements << described_class::Atom.new(value: "sd") }.to raise_error(FrozenError)
  end

  it "pretty-prints nodes for round-trip debugging" do
    ast = Cyclotone::MiniNotation::Parser.new.parse('"kick/snare" bd*2')

    expect(ast.to_mn).to eq('"kick/snare" bd*2')
    expect(Cyclotone::MiniNotation::Parser.new.parse(ast.to_mn)).to eq(ast)
  end
end
