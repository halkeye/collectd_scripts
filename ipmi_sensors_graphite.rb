#!/usr/bin/env ruby
#require 'rubygems'
require 'rubyipmi'
require 'optparse'
require 'inifile'
require 'simple-graphite'

options = {
  :interval => 10,
  :config => File.dirname(__FILE__) + '/config.ini',
  :debug => false
}
OptionParser.new do |opts|
  opts.banner = "Usage: plex_graphite.rb [options] configkey"
  opts.on("-c", "--config FILE", "Filename of config file") do |config|
    options[:config] = config
  end
  opts.on("-i", "--interval INTERVAL", "sleep time") do |interval|
    options[:interval] = interval.to_i
  end
  opts.on("-d", "--[no-]debug", "Debug") do |d|
    options[:debug] = d
  end
end.parse!

ini = IniFile.load(options[:config])
config = ini["ipmi_sensors_graphite.rb:#{ARGV[0]}"]

g = Graphite.new({:host => ini['graphite']['host'], :port =>  ini['graphite']['port'].to_i, :type => :udp})

while true do
  conn = Rubyipmi.connect(config['username'], config['password'], config['host'], "ipmitool")
  g.push_to_graphite do |graphite|
    conn.sensors.list.each_pair do |sensor_name, sensor|
      next if sensor[:status] == "N/A" or sensor[:status] == "na"
      value = sensor[:state] ? sensor[:value] : sensor[:status]
      str = "#{config['name']||host}.ipmi.gauge-#{sensor_name} #{value} #{g.time_now}"
      puts str if options[:debug]
      graphite.puts str
    end
  end
  sleep options[:interval]
end

