#!/usr/bin/env ruby
#
# Written by Gavin Mogan (gavin@kodekoan.com)

require 'rubygems'
require 'transmission-rpc'

# Enable auto flush
STDOUT.sync = true

hostname=ENV['COLLECTD_HOSTNAME'] || `hostname -f`.chomp!
interval=ENV['COLLECTD_INTERVAL'] || 10

client = Transmission

status_names = {
  6 => "seeding",
  5 => "queued_seeding",
  4 => "downloading",
  3 => "queued_downloading",
  2 => "checking",
  1 => "queued_checking",
  0 => "paused",
}

while (1) do
  totals = {
    'downloading' => 0,
    'paused' => 0
  }
  total = 0
  client.torrents.each do |torrent|
    status = status_names[torrent.status.to_i]
    totals[status] ||= 0
    totals[status] += 1

    # secondary generic status
    if (torrent.percent_done == 1)
      status = "done"
    else
      status = "incomplete"
    end

    totals[status] ||= 0
    totals[status] += 1

    total += 1
  end
  puts "PUTVAL \"#{hostname}/transmission/gauge-all\" interval=#{interval.to_s} N:#{total.to_s}\n";
  totals.each do |key,value|
    puts "PUTVAL \"#{hostname}/transmission/gauge-#{key}\" interval=#{interval.to_s} N:#{value.to_s}\n";
  end
  sleep(interval.to_i)
end

