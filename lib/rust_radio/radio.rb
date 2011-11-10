module RustRadio
  class Radio

    def initialize
      config = YAML.load_file("config.yml")["config"]

      @reader = FlacReader.new
      @writer = ShoutcastWriter.new(config)

      @transcoder = Transcoder.new(@reader, @writer)

      @playlist = Playlist.find(:name => config["playlist"]).first
    end

    def play
      while song_path = @playlist.next_song
        puts "playing: #{song_path}"
        stream(song_path)
      end

      # when catching error or ctrl-c
      # TODO @writer.close
    end

    # Stream a FLAC file
    def stream(file)
      @transcoder.transcode(file)
    end

  end
end

