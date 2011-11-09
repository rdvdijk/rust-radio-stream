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
    end

    # Stream a FLAC file
    def stream(file)
      begin
        @transcoder.transcode(file)
      ensure
        @writer.close
      end
    end

  end
end

