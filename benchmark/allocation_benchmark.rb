# frozen_string_literal: true

require_relative "../lib/cyclotone"

GC.start
before = GC.stat(:total_allocated_objects)

pattern = Cyclotone::Pattern.mn("bd [sd sd] hh cp").fast(2).merge(Cyclotone::Controls.gain(0.8))
1_000.times { pattern.query_cycle(0) }

after = GC.stat(:total_allocated_objects)
puts "allocated_objects=#{after - before}"
