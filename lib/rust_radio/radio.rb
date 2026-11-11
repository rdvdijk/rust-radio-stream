# frozen_string_literal: true

module RustRadio
  # The main radio class, intializes the playlist and posts to social media
  class Radio
    def initialize(config_file)
      @config = YAML.load_file(config_file)['config']
      initialize_radio
      initialize_social_media
      initialize_playlist
    end

    def play
      @playlist.play do |song|
        update_show_title if @playlist.next_show?
        stream(song)
      end
    rescue Interrupt => e
      p e
      @transcoder.close
    end

    private

    def initialize_radio
      flac_reader   = FlacReader.new
      mp3_writer    = MP3Writer.new(@config)
      vorbis_writer = VorbisWriter.new(@config)
      @transcoder   = Transcoder.new(flac_reader, [mp3_writer, vorbis_writer])
    end

    def initialize_social_media
      @tweeter         = Tweeter.new(@config['twitter'])
      @facebook_poster = FacebookPoster.new(@config['facebook'])
      @tune_in         = TuneIn.new(@config['tune_in'])
    end

    def initialize_playlist
      playlist_name = @config['playlist']
      @playlist = Playlist.where(name: playlist_name).first
      raise "Can't find playlist '#{playlist_name}'" unless @playlist
    end

    def stream(song)
      RustRadio.logger.info("playing: #{song.full_file_path} | #{song.stream_title}")
      social_media_next_song!(song)
      @transcoder.transcode(song)
    end

    def update_show_title
      social_media_next_show!(@playlist.current_show)
    end

    def social_media_next_song!(song)
      @tune_in.song_update(song)
    end

    def social_media_next_show!(show)
      @tweeter.show_update(show.long_title)
      @facebook_poster.show_update(show)
    end
  end
end
