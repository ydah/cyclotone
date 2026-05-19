# frozen_string_literal: true

require "benchmark"
require_relative "../lib/cyclotone"

iterations = Integer(ENV.fetch("CYCLOTONE_BENCH_N", "1000"))
span = Cyclotone::TimeSpan.new(0, 4)
pattern = Cyclotone::Pattern.mn("bd [sd sd] hh cp").fast(2)
combined = pattern.merge(Cyclotone::Controls.gain(Cyclotone::Oscillators.sine))

Benchmark.bm(16) do |x|
  x.report("Pattern.mn") { iterations.times { Cyclotone::Pattern.mn("bd [sd sd] hh cp") } }
  x.report("query_span") { iterations.times { pattern.query_span(span) } }
  x.report("combine/merge") { iterations.times { combined.query_span(span) } }
end
