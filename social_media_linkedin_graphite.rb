#!/usr/bin/env ruby
require 'optparse'
require 'inifile'
require 'simple-graphite'
require 'linkedin'

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

$username = ARGV[0]
$ini = IniFile.load(options[:config])

def get_graphite
  return Graphite.new({
    :host => $ini['graphite']['host'],
    :port => $ini['graphite']['port'].to_i,
    :type => :udp
  })
end
def get_config(key)
  return $ini["social_media:linkedin:#{$username}"][key] || $ini["social_media:linkedin"][key]
end

client = LinkedIn::Client.new(
  get_config('client_id'),
  get_config('client_secret')
)

if (!get_config('oauth_token'))
  request_token = client.request_token({}, :scope => 'r_basicprofile')
  rtoken = request_token.token
  rsecret = request_token.secret

  puts "To authorize, goto #{request_token.authorize_url}"
  pin = $stdin.gets.chomp
  tokens = client.authorize_from_request(rtoken, rsecret, pin)

  puts "[social_media:linkedin:#{$username}]"
  puts "oauth_token=#{tokens[0]}"
  puts "oauth_token_secret=#{tokens[1]}"
  return
end


g = get_graphite
while true do
  g.push_to_graphite do |graphite|
    client.authorize_from_access(
      get_config('oauth_token'),
      get_config('oauth_token_secret')
    )

    value = client.profile(:fields => %w(num-connections)).num_connections.to_i
    str = "social.linkedin.#{$username}.num_connections #{value} #{g.time_now}"

    puts str if options[:debug]
    graphite.puts str
  end
  sleep options[:interval]
end
