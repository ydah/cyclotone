# frozen_string_literal: true

require "benchmark"
require_relative "../lib/cyclotone"

iterations = Integer(ENV.fetch("CYCLOTONE_BENCH_N", "1000"))
span = Cyclotone::TimeSpan.new(0, 4)
pattern = Cyclotone::Pattern.mn("bd [sd sd] hh cp").fast(2)
combined = pattern.merge(Cyclotone::Controls.gain(Cyclotone::Oscillators.sine))
both = pattern.combine_both(Cyclotone::Controls.gain("0.5 0.75 1 0.25")) do |value, controls|
  controls.is_a?(Hash) ? controls.merge(s: value) : value
end
smooth = Cyclotone::Oscillators.smooth(Cyclotone::Pattern.mn("0 1 0.25 0.75"))
backend = Cyclotone::Backends::NullBackend.new
scheduler = Cyclotone::Scheduler.new(backend: backend, cps: 1, lookahead_cycles: 1)
scheduler.update_pattern(:bench, combined)

Benchmark.bm(16) do |x|
  x.report("Pattern.mn") { iterations.times { Cyclotone::Pattern.mn("bd [sd sd] hh cp") } }
  x.report("query_span") { iterations.times { pattern.query_span(span) } }
  x.report("combine/merge") { iterations.times { combined.query_span(span) } }
  x.report("combine_both") { iterations.times { both.query_span(span) } }
  x.report("smooth") { iterations.times { smooth.query_span(span) } }
  x.report("scheduler") do
    iterations.times do
      scheduler.set_cycle(0)
      scheduler.render(duration: 1)
      backend.flush
    end
  end
end
