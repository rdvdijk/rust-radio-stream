# frozen_string_literal: true

require 'thor'

module RustRadio
  # Command line interface stuff
  class CLI < Thor
    desc 'add_show [PATH]', 'Add a show to the default playlist.'
    method_option :playlist, type: :string, default: 'Default'
    def add_show(path)
      raise Thor::MalformattedArgumentError, "#{path} does not exist." unless File.exist?(path)
      raise Thor::MalformattedArgumentError, "#{path} is not a directory." unless File.directory?(path)

      path = File.expand_path(path) # for display and logging; Show normalizes folder_path itself
      ui = add_show_ui(path)
      if ui.run == :add
        RustRadio.logger.info("Adding folder: #{path}")
        RustRadio::ShowAdder.new.add(path, options['playlist'], notes: ui.notes)
      else
        RustRadio.logger.info("Cancelled adding folder: #{path}")
      end
    end

    no_commands do
      def add_show_ui(path)
        date = RustRadio::ShowAdder.show_date(path)
        RustRadio::AddShowUI.new(path, options['playlist'], RustRadio::ShowAdder.flac_files(path),
                                 existing_show: RustRadio::Show.find_by(folder_path: path),
                                 year_count: date && [date.year, RustRadio::Show.in_year(date.year).count])
      end
    end

    desc 'playlist', 'Add and remove shows on a playlist, and delete shows that are on no playlist.'
    method_option :playlist, type: :string, default: 'Default'
    def playlist
      playlist = RustRadio::Playlist.find_by(name: options['playlist'])
      raise Thor::Error, "Playlist '#{options['playlist']}' does not exist." unless playlist

      RustRadio::PlaylistUI.new(playlist).run
    end

    desc 'clear', "Remove all shows (just don't!)."
    method_options really: :boolean
    def clear
      DataMapper.auto_migrate! if options['really']
    end

    desc 'play', 'Start the stream.'
    method_option :config_file, type: :string, default: 'config/config.yml'
    def play
      RustRadio::Radio.new(options['config_file']).play
    end

    desc 'web', 'Start webserver.'
    def web
      RustRadio::Web::UI.run!
    end

    desc 'rrd', 'Update RRD statistisc'
    method_option :config_file, type: :string, default: 'config/config.yml'
    def rrd
      RustRadio::RRD.new(options['config_file']).update!
    end
  end
end
