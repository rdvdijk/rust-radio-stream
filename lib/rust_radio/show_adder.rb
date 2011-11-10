require 'flacinfo'

module RustRadio
  class ShowAdder
    def add(folder_path)
      collect_files(folder_path)
      show = create_show(folder_path)
      add_songs(folder_path, show)
      add_to_playlist(show)
    end

    def collect_files(folder_path)
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
      raise "couldn't find files..?" if flac_files.empty? || !info_file
      @flac_files = flac_files
      @info_file = info_file
    end

    def create_show(folder_path)
      file = File.open(File.join(folder_path, @info_file))
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
                  setlist_identifier: "") #{date.gsub(/[^\d]/,'')}0")
      puts "Adding show: #{show.date}  |   #{show.artist}  |   #{show.title}"
      show.save
      show
    end

    def add_songs(folder_path, show)
      @flac_files.sort.each_with_index do |flac, index|
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
        putc "."
      end
    end

    def add_to_playlist(show)
      playlist = Playlist.first_or_create(name: "Default")

      max = playlist.entries.max(:sort_order)
      max = 0 if max.nil?

      playlist.entries.create(show:show, sort_order:max+1)

      puts
      puts "Added to playlist '#{playlist.name}'."
    end
  end
end
