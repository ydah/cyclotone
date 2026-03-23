# frozen_string_literal: true

require "cyclotone"

# Plays a Euclidean kick pattern with hats over OSC/SuperDirt.
# Start SuperDirt first, then run:
#   bundle exec ruby examples/euclidean_rhythms.rb

host = ENV.fetch("CYCLOTONE_OSC_HOST", "127.0.0.1")
port = ENV.fetch("CYCLOTONE_OSC_PORT", "57120").to_i

backend = Cyclotone::Backends::OSCBackend.new(host: host, port: port)
scheduler = Cyclotone::Scheduler.new(backend: backend)

kick = Cyclotone::Controls.s("bd(3,8)").gain(1.0)
hat = Cyclotone::Controls.s("hh*8").gain(0.6).pan(0.35)

scheduler.update_pattern(:d1, kick)
scheduler.update_pattern(:d2, hat)
begin
  scheduler.start
  sleep 16
ensure
  scheduler&.stop
end
