# frozen_string_literal: true

RSpec.describe Cyclotone::Stream do
  subject(:stream) { described_class.instance }

  after do
    stream.hush
    stream.instance_variable_get(:@slots).clear
    stream.instance_variable_get(:@slot_options).clear
    stream.instance_variable_get(:@transitions).clear
    stream.instance_variable_get(:@soloed).clear
    stream.instance_variable_get(:@muted).clear
  end

  it "applies jump_in relative to the current scheduler cycle" do
    stream.reset_cycles
    stream.set_cycle(8)
    stream.p(:lead, Cyclotone::Controls.s("bd"))

    stream.jump_in(:lead, 2, Cyclotone::Controls.s("sd"))

    expect(stream.slot(:lead).query_cycle(8).map { |event| event.value[:s] }).to eq(["bd"])
    expect(stream.slot(:lead).query_cycle(9).map { |event| event.value[:s] }).to eq(["bd"])
    expect(stream.slot(:lead).query_cycle(10).map { |event| event.value[:s] }).to eq(["sd"])
  end

  it "uses clutch transitions to swap events instead of stacking both patterns" do
    stream.reset_cycles
    stream.set_cycle(0)
    stream.p(:lead, Cyclotone::Controls.s("bd"))

    stream.clutch_in(:lead, 2, Cyclotone::Controls.s("sd"))

    expect(stream.slot(:lead).query_cycle(0).map { |event| event.value[:s] }).to eq(["bd"])
    expect(stream.slot(:lead).query_cycle(2).map { |event| event.value[:s] }).to eq(["sd"])
  end

  it "interpolates numeric control values across a transition" do
    stream.reset_cycles
    stream.set_cycle(0)
    stream.p(:lead, Cyclotone::Controls.note(0).gain(1.0))

    stream.interpolate_in(:lead, 4, Cyclotone::Controls.note(4).gain(0.0))

    value = stream.slot(:lead).query_cycle(2).first.value

    expect(value[:note]).to be_within(0.001).of(2.0)
    expect(value[:gain]).to be_within(0.001).of(0.5)
  end

  it "queries interpolate transition sources once per span" do
    stream.reset_cycles
    stream.set_cycle(0)
    query_counts = Hash.new(0)
    current = counting_anchor_pattern(query_counts, :current, 0)
    replacement = counting_anchor_pattern(query_counts, :replacement, 8)

    stream.p(:lead, current)
    stream.interpolate_in(:lead, 4, replacement)
    stream.slot(:lead).query_cycle(0)

    expect(query_counts).to eq(current: 1, replacement: 1)
  end

  it "fades active slots out over the requested number of cycles" do
    stream.reset_cycles
    stream.p(:lead, Cyclotone::Controls.s("bd").gain(1.0))

    stream.fade_out(2)

    first_gain = stream.slot(:lead).query_cycle(0).first.value[:gain]
    later_gain = stream.slot(:lead).query_cycle(3).first.value[:gain]

    expect(first_gain).to be > later_gain
    expect(later_gain).to eq(0.0)
  end

  it "applies gain envelopes to non-hash values" do
    stream.reset_cycles
    stream.p(:lead, Cyclotone::Pattern.pure("bd"))

    stream.fade_out(2)

    value = stream.slot(:lead).query_cycle(0).first.value
    expect(value).to include(value: "bd", gain: be_between(0.0, 1.0))
  end

  it "preserves explicit zero gain in envelopes" do
    stream.reset_cycles
    stream.p(:lead, Cyclotone::Controls.s("bd").gain(0.0))

    stream.fade_out(2)

    expect(stream.slot(:lead).query_cycle(0).first.value[:gain]).to eq(0.0)
  end

  it "simplifies completed transition wrappers to their replacements" do
    stream.reset_cycles
    stream.set_cycle(0)
    stream.p(:lead, Cyclotone::Controls.s("bd"))

    stream.jump_in(:lead, 1, Cyclotone::Controls.s("sd"))
    stream.set_cycle(2)

    expect(stream.slot(:lead).query_cycle(2).map { |event| event.value[:s] }).to eq(["sd"])
    expect(stream.instance_variable_get(:@transitions)).not_to have_key(:lead)
  end

  it "uses a completed transition replacement as the source for a new transition" do
    stream.reset_cycles
    stream.set_cycle(0)
    stream.p(:lead, Cyclotone::Controls.s("bd"))

    stream.jump_in(:lead, 1, Cyclotone::Controls.s("sd"))
    stream.set_cycle(2)
    stream.xfade_in(:lead, 1, Cyclotone::Controls.s("hh"))

    values = stream.slot(:lead).query_cycle(2).map { |event| event.value[:s] }
    expect(values).to include("sd", "hh")
  end

  def counting_anchor_pattern(query_counts, key, note_offset)
    Cyclotone::Pattern.new do |span|
      query_counts[key] += 1
      [0, Rational(1, 4), Rational(1, 2), Rational(3, 4)].filter_map do |start|
        whole = Cyclotone::TimeSpan.new(start, start + Rational(1, 8))
        part = span.intersection(whole)
        next unless part

        Cyclotone::Event.new(whole: whole, part: part, value: { note: note_offset + (start * 8).to_i })
      end
    end
  end
end
