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
      @streamer.sync # sleep a while
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

    def buffer_to_samples(buffer)
      samples = []
      buffer.each do |left, right|
        samples << left << right
      end
      samples
    end

  end
end

# # monkey patch, is fixed in unreleased version of ruby-audio
# class RubyAudio::Buffer
#   def real_each
#     self.real_size.times do |i|
#       yield self[i]
#     end
#   end
# end
