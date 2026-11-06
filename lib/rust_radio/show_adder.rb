# frozen_string_literal: true

require 'flacinfo'

module RustRadio
  # Used to add FLAC shows to the database
  class ShowAdder
    # The FLAC files in a folder, in the order they will be added as songs.
    def self.flac_files(folder_path)
      Dir.children(folder_path).grep(/\.flac$/).sort
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
      @info_file = Dir.children(@folder_path).reverse.find do |entry|
        entry =~ /\.txt$/ && entry !~ /orig/ && entry !~ /ffp/
      end
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
      info = FlacInfo.new(File.join(@folder_path, flac))
      streaminfo = info.streaminfo
      samplerate = streaminfo['samplerate']
      raise "Incompatible sample rate (#{samplerate}) in #{flac}" unless samplerate == 44_100

      { file_path: flac,
        title: info.tags['TITLE'] || raise("Tag 'TITLE' not set in #{flac}"),
        length: (streaminfo['total_samples'] / samplerate.to_f) * 1000 }
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
