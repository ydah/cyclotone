# frozen_string_literal: true

require "cyclotone"

# Plays a short live-coded set over SuperDirt using the DSL and Stream singleton.
# Start SuperDirt first, then run:
#   bundle exec ruby examples/live_coding_session.rb

include Cyclotone::DSL

host = ENV.fetch("CYCLOTONE_OSC_HOST", "127.0.0.1")
port = ENV.fetch("CYCLOTONE_OSC_PORT", "57120").to_i

stream.use_backend(Cyclotone::Backends::OSCBackend.new(host: host, port: port))
setcps Rational(9, 16)
d1 s("bd [sd sd] hh cp").gain(0.85)
d2 note("0 2 4 7").scale(:minor, root: "c4").s("superpiano")
d3 s("hh*8").gain(0.6).pan(0.8)

begin
  start
  sleep 8
  xfade_in(:d1, 2, s("bd*2 [~ sd] hh cp").gain(0.9))
  jump(:d2, note("7 5 4 2").scale(:minor, root: "c4").s("superpiano"))
  sleep 8
ensure
  hush
  stop
end
