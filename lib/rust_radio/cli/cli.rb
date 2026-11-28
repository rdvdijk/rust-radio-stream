# frozen_string_literal: true

require 'thor'

module RustRadio
  # Command line interface stuff
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Otherwise an option Thor doesn't know, like a mistyped --yes, would be
    # taken as the message to announce.
    check_unknown_options!

    desc 'add_show PATH', 'Add a show to the default playlist.'
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

    desc 'announce [MESSAGE]', 'Post a message to all enabled social media. Without MESSAGE, reads it from stdin.'
    method_option :config_file, type: :string, default: 'config/config.yml'
    method_option :yes, type: :boolean, aliases: '-y', desc: 'Post without asking first.'
    def announce(message = nil)
      message = (message || $stdin.read).strip
      raise Thor::Error, 'The message is empty.' if message.empty?

      social_media = RustRadio::SocialMedia.new(YAML.load_file(options['config_file'])['config'])
      raise Thor::Error, 'No social media are enabled in the config.' if social_media.enabled.empty?

      preview_announcement(social_media, message)
      return say('Not posted.') unless options['yes'] || announcement_confirmed?

      social_media.announce(message).each { |name, thread| say("#{name}: #{thread.value ? 'posted' : 'failed'}") }
    end

    no_commands do
      def preview_announcement(social_media, message)
        social_media.enabled.each do |name, poster|
          texts = poster.announcement_texts(message)
          say("#{name}#{" (#{texts.size} posts, as a thread)" if texts.size > 1}:", :bold)
          texts.each { |text| say("#{text.gsub(/^/, '  ')}\n\n") }
        end
        disabled = social_media.disabled_names
        say("Disabled in the config: #{disabled.join(', ')}") if disabled.any?
      end

      # A message from stdin leaves nothing to answer with, so that needs --yes.
      def announcement_confirmed?
        raise Thor::Error, 'Pass --yes to post without a terminal to confirm on.' unless $stdin.tty?

        # Not Thor's yes?, which loads readline and so a deprecation warning.
        print 'Post this? [y/N] '
        %w[y yes].include?($stdin.gets.to_s.strip.downcase)
      end
    end

    desc 'rrd', 'Update RRD statistisc'
    method_option :config_file, type: :string, default: 'config/config.yml'
    def rrd
      RustRadio::RRD.new(options['config_file']).update!
    end
  end
end
