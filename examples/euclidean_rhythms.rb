# frozen_string_literal: true

require "cyclotone"

pattern = Cyclotone::Pattern.mn("bd(3,8)")
pp pattern.query_cycle(0)
