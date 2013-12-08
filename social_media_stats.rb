#!/usr/bin/env ruby
#
# Written by Gavin Mogan (gavin@kodekoan.com)

require 'rubygems'
require 'bundler/setup'
require "json"
require 'eventmachine'
require "open-uri"
require "twitter"
require "oauth"

# Enable auto flush
STDOUT.sync = true

@hostname="social"
@interval=60

@config_file = ARGV[0] || 'social_media_config.json'
@config = JSON.parse(open(@config_file) { |f| f.read })

@twitter_clients = {}
TWITTER_MAX_ATTEMPTS_PER_USER = 3

def output_gauge(project_name, type, key, value)
  puts "PUTVAL \"#{@hostname}/#{project_name}-#{type}/gauge-#{key}\" interval=#{@interval.to_i} N:#{value.to_i}\n";
end

def get_twitter_oauth(username)
  @config['config']['twitter']['users'] = {} unless @config['config']['twitter'].has_key? "users"

  c = OAuth::Consumer.new(
    @config['config']['twitter']['consumer_key'],
    @config['config']['twitter']['consumer_secret'],
    {
      :site => "https://api.twitter.com",
      :scheme => :header
    }
  )
  request_token = c.get_request_token
  $stderr.puts "\nPlease goto https://api.twitter.com/oauth/authorize?oauth_token=#{request_token.token} to register this app\n"
  $stderr.puts
  $stderr.puts "Enter PIN: "
  pin = (gets.chomp).to_i
  at = request_token.get_access_token(:oauth_verifier => pin)

  @config['config']['twitter']['users'][username] = {}
  @config['config']['twitter']['users'][username]['oauth_token'] = at.params[:oauth_token]
  @config['config']['twitter']['users'][username]['oauth_token_secret'] = at.params[:oauth_token_secret]
  File.open(@config_file, 'w') { |f| f.write(JSON.pretty_generate(@config)) }

end

def collect_twitter(project_name)
  username = @config["projects"][project_name]["twitter"]

  client = @twitter_clients[username]
  if (!client) then

    begin
      oauth_data = @config['config']['twitter']['users'][username]
    rescue
      get_twitter_oauth(username)
    end

    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = @config['config']['twitter']['consumer_key'].to_s
      config.consumer_secret     = @config['config']['twitter']['consumer_secret'].to_s
      config.access_token        = oauth_data['oauth_token'].to_s
      config.access_token_secret = oauth_data['oauth_token_secret'].to_s
    end
    @twitter_clients[username] = client
  end

  begin
    user = client.user(username)
    output_gauge(project_name, "twitter", "followers", user.followers_count)
    EM.add_timer(@interval) {collect_twitter(project_name) };
  rescue Twitter::Error::TooManyRequests => error
    $stderr.puts "[Twitter] sleeping " + username + " for " + error.rate_limit.reset_in.to_f.to_s
    # NOTE: Your process could go to sleep for up to 15 minutes but if you
    # retry any sooner, it will almost certainly fail with the same exception.
    EM.add_timer(error.rate_limit.reset_in.to_f) { collect_twitter(project_name) }
  end

end

def collect_facebook(project_name)
  url = "http://graph.facebook.com/"+@config["projects"][project_name]["facebook"]+"?fields=likes,talking_about_count"
  saltineData = JSON.parse(open(url) { |f| f.read })
  output_gauge(project_name, "facebook", "likes", saltineData["likes"].to_i)
  # who is talking about it
  output_gauge(project_name, "facebook", "talking_about", saltineData["talking_about_count"].to_i)
        
  EM.add_timer(@interval) { collect_facebook(project_name) }
end

EM.run do
  @config["projects"].keys.each do |project|
    @config["projects"][project].keys.each do |type|
      if (type == "facebook") then
        collect_facebook(project)
      end
      if (type == "twitter") then
        collect_twitter(project)
      end
    end
  end
end
