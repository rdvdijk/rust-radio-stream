namespace :db do
  desc "Run ActiveRecord migrations."
  task :migrate do #=> :environment do
    require './init'
    #ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
    context = ActiveRecord::MigrationContext.new('db/migrate')
    if ENV['VERSION']
      context.migrate(ENV['VERSION'].to_i)
    else
      context.migrate
    end
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
        puts "  Show ##{show.id} :: #{File.exist? show.folder_path} :: #{show.date} #{show.city_state} #{show.artist}"

        show.songs.each do |song|
          puts "    Song #{song.id} :: #{song.full_file_path} #{File.exist? song.full_file_path} :: #{song.sort_order}. #{song.title} (#{song.length})"

          raise "File not found: #{song.full_file_path}" unless File.exist?(song.full_file_path)
        end
      end
    end
  end

  desc "Do a dry-run of playing songs."
  task :dryrun do
    require 'pry'
    require './init'
    RustRadio::Playlist.all.each do |playlist|
      playlist.play do |song|
        puts song.stream_title
      end
    end
  end
end
