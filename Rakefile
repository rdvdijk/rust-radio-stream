# frozen_string_literal: true

namespace :db do
  desc 'Run ActiveRecord migrations.'
  task :migrate do #=> :environment do
    require './init'
    context = ActiveRecord::MigrationContext.new('db/migrate')
    if ENV['VERSION']
      context.migrate(ENV['VERSION'].to_i)
    else
      context.migrate
    end
  end
end

namespace :sanity do
  desc 'Do a sanity check of all playlists, shows and songs.'
  task :check do
    require 'pry'
    require './init'
    RustRadio::Playlist.all.each do |playlist|
      puts "Playlist ##{playlist.id} : #{playlist.name}"

      playlist.entries.each do |entry|
        show = entry.show
        puts "  Show ##{show.id} :: #{File.exist? show.folder_path} :: #{show.date} #{show.city_state} #{show.artist}"

        show.songs.each do |song|
          exists = File.exist?(song.full_file_path)
          puts "    Song #{song.id} :: #{song.full_file_path} #{exists} :: " \
               "#{song.sort_order}. #{song.title} (#{song.length})"

          raise "File not found: #{song.full_file_path}" unless exists
        end
      end
    end
  end

  desc 'Decode all songs with `flac --test` and report the ones that fail. Only reads the database.'
  task :test do
    require 'io/console'
    require 'open3'
    require './init'

    # Lowest CPU and idle IO priority (inherited by the flac processes), so
    # the test doesn't starve the transcoder of the running stream.
    Process.setpriority(Process::PRIO_PROCESS, 0, 19)
    system('ionice', '-c', '3', '-p', Process.pid.to_s, err: File::NULL)

    # On a terminal the progress line is redrawn in place, so it's cut to the
    # terminal width: a wrapped line can't be cleared with \r. In a log every
    # song gets its own line.
    tty = $stdout.tty?
    width = tty ? $stdout.winsize[1].nonzero? || 80 : nil

    failures = []
    count = 0
    total = RustRadio::Song.count
    RustRadio::Song.includes(:show).find_each do |song|
      count += 1
      path = song.full_file_path
      progress = "[#{count}/#{total}, #{failures.size} failed] #{path}"
      if tty
        print progress[0, width - 1]
        $stdout.flush
      else
        puts progress
      end
      error = if File.exist?(path)
                output, status = Open3.capture2e('flac', '--test', '--silent', path)
                output.strip unless status.success?
              else
                'file not found'
              end
      print "\r\e[K" if tty
      next unless error

      failures << song
      puts "Song ##{song.id} (show ##{song.show_id}) #{path}\n  #{error.gsub("\n", "\n  ")}"
    end

    puts "Tested #{count} songs, #{failures.size} failed."
    exit 1 if failures.any?
  end

  desc 'Do a dry-run of playing songs.'
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

# RuboCop is a development gem, so it isn't installed on the server, where
# deploys run `rake db:migrate`.
begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
  task default: %i[rubocop]
rescue LoadError
  nil
end
