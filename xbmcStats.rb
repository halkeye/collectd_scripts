#!/usr/bin/env ruby
#
# Written by Gavin Mogan (gavin@kodekoan.com)

require 'rubygems'
require 'mysql2'

# Enable auto flush
STDOUT.sync = true

hostname=ENV['COLLECTD_HOSTNAME'] || `hostname -f`.chomp!
interval=ENV['COLLECTD_INTERVAL'] || 10

mysql_host = ARGV[0] || 'localhost'
mysql_user = ARGV[1] || 'root'
mysql_pass = ARGV[2] || ''

client = Mysql2::Client.new(:host=>mysql_host, :username=>mysql_user, :password=>mysql_pass);
results = client.query("show databases like 'xbmc_video%'");
databaseVer = 0;
results.each(:as => :array) do |row|
  num = row[0].match('xbmc_video(\d+)$')[1];
  if (num.to_i > databaseVer)
    databaseVer = num.to_i
  end
end


client.query("use xbmc_video" + databaseVer.to_s);
while (1) do
  results = client.query("SELECT 
                         SUM(totalCount) AS collectedEpisodes, 
                         SUM(watchedCount) AS watchedEpisodes, 
                         SUM(IF(watchedCount>0 AND watchedCount<totalCount, 1, 0)) as inProgressShows, 
                         SUM(IF(watchedCount>0 AND watchedCount=totalCount, 1, 0)) as completedShows,
                         COUNT(1) as totalShows
                         FROM tvshowview");
  results.each do |row|
    row.each do |key,value|
      puts "PUTVAL \"#{hostname}/xbmc-tvshows/gauge-#{key}\" interval=#{interval.to_i} N:#{value.to_i.to_s}\n";
    end
  end
  results = client.query("select SUM(playCount>0) AS watched, COUNT(*) AS collected FROM movieview");
  results.each do |row|
    row.each do |key,value|
      puts "PUTVAL \"#{hostname}/xbmc-movies/gauge-#{key}\" interval=#{interval.to_i} N:#{value.to_i.to_s}\n";
    end
  end
  sleep(interval.to_i)
end

