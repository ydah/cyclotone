# frozen_string_literal: true

RSpec.describe Cyclotone do
  it "has a version number" do
    expect(Cyclotone::VERSION).not_to be nil
  end

  it "loads the core phase-1 types" do
    expect(Cyclotone::TimeSpan).to be_a(Class)
    expect(Cyclotone::Event).to be_a(Class)
    expect(Cyclotone::Pattern).to be_a(Class)
  end
end
