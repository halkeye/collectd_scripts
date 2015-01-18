#!/usr/bin/env ruby
#require 'rubygems'
require 'nokogiri'
require 'inifile'
require 'simple-graphite'
require "net/http"
require "uri"

$INTERVAL = 10;

ini = IniFile.load(ARGV[1] || 'config.ini')
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
      graphite.puts "plex.user_activity.#{user} #{users[user]} #{g.time_now}"
    end
  end
  sleep $INTERVAL
end