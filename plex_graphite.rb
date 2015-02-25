#!/usr/bin/env ruby
#require 'rubygems'
require 'nokogiri'
require 'inifile'
require 'simple-graphite'
require "net/http"
require "uri"
require 'optparse'

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
g = Graphite.new({:host => ini['graphite']['host'], :port =>  ini['graphite']['port'].to_i, :type => :udp})
# config = ini["plex_graphite.rb.rb:#{ARGV[0]}"]

http = Net::HTTP.new(ini['plex']['host'], ini['plex']['port'].to_i)
while true do
  g.push_to_graphite do |graphite|
    response = http.request(Net::HTTP::Get.new('/status/sessions'))
    @doc = Nokogiri::XML(response.body)
    # string(MediaContainer/Video/@grandparentTitle)
    # show name
    users = {}
    @doc.xpath( "//MediaContainer/Video/User" ).each do |user|
      username = user["title"]
      users[username] = 0 unless users.has_key?(username)
      users[username] = users[username] + 1
    end
    users.keys.each do |user|
      str = "plex.user_activity.#{user} #{users[user]} #{g.time_now}"
      graphite.puts str
      puts str if options[:debug]
    end
  end
  sleep options[:interval]
end
