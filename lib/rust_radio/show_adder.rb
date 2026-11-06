# frozen_string_literal: true

require 'rust_radio/flac_details'

module RustRadio
  # Used to add FLAC shows to the database
  class ShowAdder
    # The FLAC files in a folder, in the order they will be added as songs.
    def self.flac_files(folder_path)
      Dir.children(folder_path).grep(/\.flac$/).sort
    end

    # The info file of a show folder (artist, date, venue, city, festival, one
    # per line), or nil if there is none.
    def self.info_file(folder_path)
      Dir.children(folder_path).reverse.find do |entry|
        entry =~ /\.txt$/ && entry !~ /orig/ && entry !~ /ffp/
      end
    end

    # The date of the show, from its info file; nil if it can't be read.
    def self.show_date(folder_path)
      file = info_file(folder_path)
      return unless file

      Date.parse(File.readlines(File.join(folder_path, file), chomp: true)[1].to_s)
    rescue Date::Error
      nil
    end

    def add(folder_path, playlist_name)
      @folder_path = folder_path
      @playlist_name = playlist_name

      begin
        Show.transaction do |_t|
          collect_files
          create_show
          add_songs
          update_show_length
          add_to_playlist
        end
      rescue StandardError => e
        RustRadio.logger.error("ERROR: #{e}")
      end
    end

    def collect_files
      @flac_files = self.class.flac_files(@folder_path)
      @info_file = self.class.info_file(@folder_path)
      raise "Could not find files in #{@folder_path}" if @flac_files.empty? || !@info_file
    end

    def create_show
      @show = Show.new(show_attributes)

      unless @show.valid?
        RustRadio.logger.info("Could not add show: #{@show.errors.full_messages.join(',')}")
        raise 'Show has already been added (?).'
      end

      RustRadio.logger.info("Adding show: #{@show.date} : #{@show.artist} @ #{@show.city_state}")
      @show.save!
    end

    def show_attributes
      lines = File.readlines(File.join(@folder_path, @info_file), chomp: true)
      artist, date, venue, city_state, festival = lines

      { folder_path: @folder_path,
        artist: artist,
        date: Date.parse(date),
        city_state: city_state,
        venue: venue,
        festival: festival,
        info_file: lines.join('\n'),
        setlist_identifier: "#{date.gsub(/[^\d]/, '')}0" }
    end

    def add_songs
      @flac_files.each_with_index do |flac, index|
        @show.songs.create(**song_attributes(flac), sort_order: index + 1)
        $stdout.putc '.'
      end
      $stdout.puts
    end

    def song_attributes(flac)
      details = FlacDetails.new(@folder_path, flac)
      raise "#{flac}: #{details.warnings.join('; ')}" if details.warnings.any?

      { file_path: flac, title: details.title, length: details.length }
    end

    def update_show_length
      @show.length = @show.songs.sum(:length)
      @show.save!
    end

    def add_to_playlist
      @playlist = Playlist.find_or_create_by!(name: @playlist_name)
      @playlist.entries.create(show: @show)

      RustRadio.logger.info("Added to playlist '#{@playlist.name}'.")
    end
  end
end
