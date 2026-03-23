# frozen_string_literal: true

require "cyclotone"

include Cyclotone::DSL

setcps Rational(9, 16)
d1 s("bd [sd sd] hh cp").gain(0.85)
d2 note("0 2 4 7").scale(:minor, root: "c4").s("superpiano")
