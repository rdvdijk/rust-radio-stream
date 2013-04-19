namespace :db do
  desc "Run ActiveRecord migrations."
  task :migrate do #=> :environment do
    ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
  end
end

namespace :sanity do
  desc "Do a sanity check of all playlists, shows and songs."
  task :check do
    require 'pry'
    require './init'
    RustRadio::Playlist.all.each do |playlist|
      puts "Playlist ##{playlist.id} : #{playlist.name}"

      playlist.entries.each do |entry|
        show = entry.show
        puts "  Show ##{show.id} :: #{File.exists? show.folder_path} :: #{show.date} #{show.title} #{show.artist}"

        show.songs.each do |song|
          puts "    Song #{song.id} :: #{File.exists? song.full_file_path} :: #{song.sort_order}. #{song.title} (#{song.length})"

          raise "File not found: #{song.full_file_path}" unless File.exists?(song.full_file_path)
        end
      end
    end
  end
end