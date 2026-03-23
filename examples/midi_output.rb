# frozen_string_literal: true

require "cyclotone"

melody = Cyclotone::Controls.note("0 2 4 7").scale(:major, root: "c4")
pp melody.query_cycle(0)
