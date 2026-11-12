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

    INFO_FIELDS = %i[artist date_text venue city_state festival].freeze

    # The fields of a show's info file, plus :lines (all of them) and :date
    # (parsed from :date_text, nil if it isn't a date). Nil without an info file.
    def self.read_info(folder_path)
      file = info_file(folder_path)
      return unless file

      lines = File.readlines(File.join(folder_path, file), chomp: true)
      info = INFO_FIELDS.zip(lines).to_h
      info.merge(lines:, date: parse_date(info[:date_text]))
    end

    def self.parse_date(text)
      Date.parse(text.to_s)
    rescue Date::Error
      nil
    end

    def self.show_date(folder_path)
      read_info(folder_path)&.dig(:date)
    end

    # +notes+: free text saved with the show, for example why it was added.
    def add(folder_path, playlist_name, notes: nil)
      @folder_path = folder_path
      @playlist_name = playlist_name
      @notes = notes

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
      info = self.class.read_info(@folder_path)
      raise "Can't read the date '#{info[:date_text]}' in #{@info_file}" unless info[:date]

      { folder_path: @folder_path,
        **info.slice(:artist, :date, :venue, :city_state, :festival),
        notes: @notes,
        info_file: info[:lines].join('\n'),
        setlist_identifier: self.class.setlist_identifier(info[:date], info[:date_text]) }
    end

    # The show's identifier on sugarmtn.org, which numbers the shows of a day:
    # 0 for the only show, 1 for the early show and 2 for the late show.
    def self.setlist_identifier(date, date_text)
      suffix = case date_text
               when /\bearly\b/i then '1'
               when /\blate\b/i then '2'
               else '0'
               end
      "#{date.strftime('%Y%m%d')}#{suffix}"
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
