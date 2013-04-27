module RustRadio
  class Writer

    def initialize(config, type)
      # Shout streamers
      @streamers = []

      config[type]["servers"].each do |mount|
        streamer = RustRadio::Streamer.new(config, mount)
        streamer.connect
        @streamers << streamer
      end
    end

    def update(song)
      update_metadata(song)
    end

    def write(samples)
      raise NotImplementedError
    end

    def close
      @streamers.map(&:disconnect)
    end

    def delay
      minimum_delay
    end

    def minimum_delay
      @streamers.map(&:delay).min
    end

    def maximum_delay
      @streamers.map(&:delay).max
    end

    private

    # Stream the given MP3/Vorbis data to the SHOUTcast/Icecast server.
    def shout(data)
      @streamers.each do |streamer|
        streamer.send data
      end
    end

    def update_metadata(song)
      metadata = ShoutMetadata.new
      metadata.add "song", song.stream_title

      @streamers.each do |streamer|
        streamer.metadata = metadata
      end
    end

  end
end
