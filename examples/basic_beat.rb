# frozen_string_literal: true

require "cyclotone"

include Cyclotone::DSL

beat = s("bd sd hh cp").gain(0.9)
d1 beat

pp beat.query_cycle(0)
