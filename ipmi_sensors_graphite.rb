#!/usr/bin/env ruby
#require 'rubygems'
puts ENV['GEM_PATH'].inspect
require 'rubyipmi'
require 'inifile'
require 'simple-graphite'

$INTERVAL = 10;

ini = IniFile.load(ARGV[1] || 'config.ini')
config = ini["ipmi_sensors_graphite.rb:#{ARGV[0]}"]

g = Graphite.new({:host => ini['graphite']['host'], :port =>  ini['graphite']['port'].to_i, :type => :udp})

while true do
  conn = Rubyipmi.connect(config['username'], config['password'], config['host'])
  g.push_to_graphite do |graphite|
    conn.sensors.list.each_pair do |sensor_name, sensor|
      next if sensor[:status] == "N/A"
      if sensor[:state]
        graphite.puts "#{config['name']||host}.ipmi.gauge-#{sensor_name} #{sensor[:value]} #{g.time_now}"
      else
        graphite.puts "#{config['name']||host}.ipmi.gauge-#{sensor_name} #{sensor[:status]} #{g.time_now}"
      end
    end
  end
  sleep $INTERVAL
end

