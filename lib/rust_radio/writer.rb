module RustRadio
  class Writer
    def initialize(config)
      # Shout streamer
      @streamer = RustRadio::Streamer.new(config)
      @streamer.connect
    end

    def update(song)
      update_metadata(song)
    end

    def write(samples)
      raise NotImplementedError
    end

    def close
      @streamer.disconnect
    end

    def sync
      @streamer.sync
    end

    def delay
      @streamer.delay
    end

    private

    # Stream the given MP3/Vorbis data to the SHOUTcast/Icecast server.
    def shout(data)
      @streamer.send data
    end

    def update_metadata(song)
      metadata = ShoutMetadata.new
      metadata.add "song", song.stream_title
      @streamer.metadata = metadata
    end

  end
end
