module RustRadio
  class ShoutcastWriter < Writer
    def initialize(config)
      super(config["shoutcast"])

      @encoder = MP3Encoder.new(config)
    end

    def write(buffer)
      stream_mp3(buffer)
    end

    private

    # Convert the given samples to MP3 data and stream it.
    def stream_mp3(buffer)
      samples = buffer_to_samples(buffer)

      in_buffer = StringIO.new
      in_buffer.write(samples.pack("v*"))
      in_buffer.seek(0)

      @encoder.encode(in_buffer) do |data|
        shout(data)
      end
    end

  end
end

