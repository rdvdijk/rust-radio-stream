#!/usr/bin/env ruby

require './init'

if ARGV.empty?
  puts "addshow.rb <folder_path>"
  exit
end

folder_path = ARGV[0]

if folder_path == "RESET"
  DataMapper.auto_migrate!
else
  adder = RustRadio::ShowAdder.new
  adder.add(folder_path)
end


