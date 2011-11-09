#!/usr/bin/env ruby

require './init'
require 'flacinfo'

include RustRadio

# remove all
[ Playlist::Entry, Playlist, Song, Show ].each do |model|
  models = model.all
  puts "Destroying #{models.size} x #{model}"
  models.map(&:destroy)
end


# Read all FLAC files and find info file:
folder_path = "/Users/roel/code/personal/shows/ny2001-06-26.csb.flac16"

flac_files = []
info_file = nil
Dir.foreach(folder_path) do |entry|
  if entry =~ /\.flac$/
    flac_files << entry
  end
  if entry =~ /\.txt$/ && entry !~ /orig/ && entry !~ /ffp/
    info_file = entry
  end
end

exit if flac_files.empty? || !info_file

file = File.open(File.join(folder_path, info_file))
lines = file.readlines.map(&:chomp)
content = lines.join('\n')

artist      = lines[0]
date        = lines[1]
venue       = lines[2]
city_state  = lines[3]
festival    = lines[4]

# Create show:
show = Show.new(folder_path: folder_path,
            artist: artist,
            date: Date.parse(date),
            title: city_state,
            info_file: content,
            setlist_url: "") # TODO
show.save

flac_files.sort.each_with_index do |flac, index|
  info = FlacInfo.new(File.join(folder_path, flac))

  streaminfo = info.streaminfo
  length = (streaminfo["total_samples"] / streaminfo["samplerate"].to_f) * 1000
  title = info.tags["TITLE"]

  song = Song.new(file_path: flac,
            title: title,
            length: length,
            sort_order: index+1,
            show: show)
  song.save
end

playlist = Playlist.new(name: "Default")
playlist.save

playlist.entries.create(show:show)
