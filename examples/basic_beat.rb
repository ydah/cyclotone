# frozen_string_literal: true

require "cyclotone"

# Plays a simple SuperDirt beat for 16 seconds.
# Start SuperCollider/SuperDirt first, then run:
#   bundle exec ruby examples/basic_beat.rb

host = ENV.fetch("CYCLOTONE_OSC_HOST", "127.0.0.1")
port = ENV.fetch("CYCLOTONE_OSC_PORT", "57120").to_i

backend = Cyclotone::Backends::OSCBackend.new(host: host, port: port)
scheduler = Cyclotone::Scheduler.new(backend: backend)

beat = Cyclotone::Controls.s("bd sd hh cp").gain(0.9)

scheduler.update_pattern(:d1, beat)
begin
  scheduler.start
  sleep 16
ensure
  scheduler&.stop
end
