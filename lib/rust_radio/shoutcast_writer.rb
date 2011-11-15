module RustRadio
  class ShoutcastWriter
    def initialize(config)
      # Shout streamer
      @streamer = RustRadio::Streamer.new(config)
      @streamer.connect

      # MP3 encoder
      @encoder = Encoder.new(config)
    end

    def update(song)
      update_metadata(song)
    end

    def write(samples)
      stream_mp3(samples)
    end

    def close
      @streamer.disconnect
    end

    private

    # Convert the given samples to MP3 data and stream it.
    def stream_mp3(samples)
      in_buffer = StringIO.new
      in_buffer.write(samples.pack("v*"))
      in_buffer.seek(0)

      @encoder.encode(in_buffer) do |data|
        shout(data)
      end
    end

    # Stream the given MP3 data to the ShoutCast server.
    def shout(mp3_data)
      @streamer.send mp3_data
      @streamer.sync # sleep a while
    end

    # Set metadata
    def update_metadata(song)
      metadata = ShoutMetadata.new
      metadata.add "song", song.stream_title
      @streamer.metadata = metadata
    end
  end
end
