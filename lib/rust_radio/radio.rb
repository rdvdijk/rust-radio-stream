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
      begin
        @playlist.play do |song_path|
          puts "playing: #{song_path}"
          stream(song_path)
        end
      rescue Interrupt => e
        @writer.close
      end
    end

    # Stream a FLAC file
    def stream(file)
      @transcoder.transcode(file)
    end
  end
end

