require 'flacinfo'

module RustRadio
  class ShowAdder
    def add(folder_path, playlist_name)
      @folder_path = folder_path
      @playlist_name = playlist_name

      Show.transaction do |t|
        begin
          collect_files
          create_show
          add_songs
          add_to_playlist
        rescue Exception => e
          puts "ERROR: #{e}"
          t.rollback
        end
      end
    end

    def collect_files
      @flac_files = []
      @info_file = nil
      Dir.foreach(@folder_path) do |entry|
        if entry =~ /\.flac$/
          @flac_files << entry
        end
        if entry =~ /\.txt$/ && entry !~ /orig/ && entry !~ /ffp/
          @info_file = entry
        end
      end
      raise "Could not find files in #{@folder_path}" if @flac_files.empty? || !@info_file
    end

    def create_show
      file = File.open(File.join(@folder_path, @info_file))
      lines = file.readlines.map(&:chomp)
      content = lines.join('\n')

      artist      = lines[0]
      date        = lines[1]
      venue       = lines[2]
      city_state  = lines[3]
      festival    = lines[4]

      # Create show:
      @show = Show.new(folder_path: @folder_path,
                  artist: artist,
                  date: Date.parse(date),
                  title: city_state,
                  info_file: content,
                  setlist_identifier: "#{date.gsub(/[^\d]/,'')}0")

      if !@show.valid?
        @show.errors.each do |error|
          puts error
        end
        raise "Show has already been added (?)."
      end

      puts "Adding show: #{@show.date} : #{@show.artist} @ #{@show.title}"
      @show.save
    end

    def add_songs
      @flac_files.sort.each_with_index do |flac, index|
        info = FlacInfo.new(File.join(@folder_path, flac))

        streaminfo = info.streaminfo
        samplerate = streaminfo["samplerate"]
        raise "Incompatible sample rate (#{samplerate}) in #{flac}" unless samplerate == 44100
        length = (streaminfo["total_samples"] / samplerate.to_f) * 1000
        title = info.tags["TITLE"] || raise("Tag 'TITLE' not set in #{flac}")

        @show.songs.create(file_path: flac,
                  title: title,
                  length: length,
                  sort_order: index + 1)
        putc "."
      end
      puts
    end

    def add_to_playlist
      @playlist = Playlist.first_or_create(name: @playlist_name)
      @playlist.entries.create(show: @show)

      puts "Added to playlist '#{@playlist.name}'."
    end
  end
end
