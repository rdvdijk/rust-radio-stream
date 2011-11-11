module RustRadio
  class Radio
    def initialize(config_file)
      config = YAML.load_file(config_file)["config"]

      @reader = FlacReader.new
      @writer = ShoutcastWriter.new(config)
      @transcoder = Transcoder.new(@reader, @writer)

      playlist_name = config["playlist"]
      @playlist = Playlist.first(:name => playlist_name)
      raise "Can't find playlist '#{playlist_name}'" unless @playlist
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

    def stream(file)
      @transcoder.transcode(file)
    end
  end
end

