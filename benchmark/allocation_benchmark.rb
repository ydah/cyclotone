# frozen_string_literal: true

require_relative "../lib/cyclotone"

GC.start
before = GC.stat(:total_allocated_objects)

pattern = Cyclotone::Pattern.mn("bd [sd sd] hh cp").fast(2).merge(Cyclotone::Controls.gain(0.8))
backend = Cyclotone::Backends::NullBackend.new
scheduler = Cyclotone::Scheduler.new(backend: backend, cps: 1, lookahead_cycles: 1)
scheduler.update_pattern(:bench, pattern)

1_000.times do
  pattern.query_cycle(0)
  scheduler.set_cycle(0)
  scheduler.render(duration: 1)
  backend.flush
end

after = GC.stat(:total_allocated_objects)
puts "allocated_objects=#{after - before}"
