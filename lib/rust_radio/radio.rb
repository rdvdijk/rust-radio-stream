module RustRadio
  class Radio

    def initialize(config_file)
      @config = YAML.load_file(config_file)["config"]
      initialize_radio
      initialize_social_media
      initialize_playlist
    end

    def play
      social_media_online!

      begin
        @playlist.play do |song|
          update_show_title if @playlist.next_show?
          stream(song)
        end
      rescue Interrupt => e
        p e
        @transcoder.close
      end
    end

    private

    def initialize_radio
      @reader           = FlacReader.new
      @shoutcast_writer = ShoutcastWriter.new(@config)
      @icecast_writer   = IcecastWriter.new(@config)
      @transcoder       = Transcoder.new(@reader, [@shoutcast_writer, @icecast_writer])
    end

    def initialize_social_media
      @tweeter         = Tweeter.new(@config["twitter"])
      @facebook_poster = FacebookPoster.new(@config["facebook"])
    end

    def initialize_playlist
      playlist_name = @config["playlist"]
      @playlist = Playlist.where(:name => playlist_name).first
      raise "Can't find playlist '#{playlist_name}'" unless @playlist
    end

    def stream(song)
      puts "playing: #{song.full_file_path}"
      @transcoder.transcode(song)
    end

    def update_show_title
      show_title = @playlist.current_show_title
      social_media_next_show!(show_title)
    end

    def social_media_next_show!(message)
      @tweeter.show_update(message)
      @facebook_poster.show_update(message)
    end

    def social_media_online!
      online_message = "Rust Radio is online! Tune in now on http://www.rustradio.org/"
      @tweeter.tweet(online_message)
      @facebook_poster.post(online_message)
    end

  end
end
