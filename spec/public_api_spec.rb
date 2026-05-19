# frozen_string_literal: true

RSpec.describe "public API compatibility" do
  it "keeps core DSL entrypoints available" do
    context = Object.new.extend(Cyclotone::DSL)

    %i[
      d1 p hush setcps reset_cycles set_cycle trigger qtrigger mtrigger
      xfade xfade_in clutch clutch_in interpolate interpolate_in jump jump_in
      anticipate solo unsolo mute unmute fade_in fade_out start stop running?
      sine cosine tri saw isaw square rand irand perlin range smooth chord scale
    ].each do |method_name|
      expect(context).to respond_to(method_name)
    end
  end

  it "keeps core pattern transforms available" do
    pattern = Cyclotone::Pattern.pure("bd")

    %i[
      fast slow early late rev palindrome hurry off swing inside outside
      every every_with_offset sometimes sometimes_by rarely almost_always almost_never
      chunk scramble shuffle iter iter_back degrade degrade_by trunc linger zoom
      stripe slowstripe spread fastspread chop striate slice splice bite chew
      randslice loop_at segment overlay superimpose layer jux jux_by weave weave_with
      when_mod fix unfix contrast mask struct
    ].each do |method_name|
      expect(pattern).to respond_to(method_name)
    end
  end
end
