module RustRadio
  class Radio
    def initialize(config_file)
      config = YAML.load_file(config_file)["config"]

      @reader           = FlacReader.new
      @shoutcast_writer = ShoutcastWriter.new(config)
      @icecast_writer   = IcecastWriter.new(config)
      @transcoder       = Transcoder.new(@reader, [@shoutcast_writer, @icecast_writer])

      @tweeter = Tweeter.new(config["twitter"])
      @facebook_poster = FacebookPoster.new(config["facebook"])

      playlist_name = config["playlist"]
      @playlist = Playlist.first(:name => playlist_name)
      raise "Can't find playlist '#{playlist_name}'" unless @playlist
    end

    def play
      # online_message = "Rust Radio is online!"
      # @tweeter.tweet(online_message)
      # @facebook_poster.post(online_message)

      begin
        @playlist.play do |song|
          # update_social_media if @playlist.next_show?
          puts "playing: #{song.full_file_path}"
          stream(song)
        end
      rescue Interrupt => e
        @transcoder.close
      end
    end

    def stream(song)
      @transcoder.transcode(song)
    end

    # def update_social_media
    #   show_title = @playlist.current_show_title
    #   @tweeter.show_update(show_title)
    #   @facebook_poster.show_update(show_title)
    # end
  end
end

