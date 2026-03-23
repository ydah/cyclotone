# frozen_string_literal: true

RSpec.describe Cyclotone::Euclidean do
  describe ".generate" do
    it "builds a tresillo pattern for (3, 8)" do
      expect(described_class.generate(3, 8)).to eq([true, false, false, true, false, false, true, false])
    end

    it "builds a cinquillo-adjacent pattern for (5, 8)" do
      expect(described_class.generate(5, 8)).to eq([true, false, true, true, false, true, true, false])
    end

    it "rotates the pattern to the left" do
      expect(described_class.generate(3, 8, 2)).to eq([false, true, false, false, true, false, true, false])
    end
  end
end
