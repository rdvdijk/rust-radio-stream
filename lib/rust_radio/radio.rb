module RustRadio
  class Radio
    def initialize(config_file)
      config = YAML.load_file(config_file)["config"]

      @reader = FlacReader.new
      @writer = ShoutcastWriter.new(config)
      @transcoder = Transcoder.new(@reader, @writer)
      @tweeter = Tweeter.new(config["twitter"])

      playlist_name = config["playlist"]
      @playlist = Playlist.first(:name => playlist_name)
      raise "Can't find playlist '#{playlist_name}'" unless @playlist
    end

    def play
      begin
        @playlist.play do |song|
          tweet if @playlist.next_show?
          puts "playing: #{song.full_file_path}"
          stream(song)
        end
      rescue Interrupt => e
        @writer.close
      end
    end

    def stream(song)
      @transcoder.transcode(song)
    end

    def tweet
      @tweeter.show_update(@playlist.current_show_title)
    end
  end
end

