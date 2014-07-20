#!/usr/bin/env ruby
require 'rubyipmi'


# Enable auto flush
STDOUT.sync = true
$INTERVAL = 10;

username, password, host, name = ARGV;

while true do
  conn = Rubyipmi.connect(username, password, host)
  conn.sensors.list.each_pair do |sensor_name, sensor|
    next if sensor[:status] == "N/A"
    puts "PUTVAL \"#{name||host}/ipmi/gauge-#{sensor_name}\" interval=#{$INTERVAL} N:#{sensor[:status]}"
  end
  sleep $INTERVAL
end

