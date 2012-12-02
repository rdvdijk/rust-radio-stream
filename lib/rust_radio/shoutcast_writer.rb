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
      in_buffer = buffer_to_io(buffer)

      @encoder.encode(in_buffer) do |data|
        shout(data)
      end
    end

    private

    def buffer_to_io(buffer)
      samples = buffer_to_samples(buffer)

      in_buffer = StringIO.new
      in_buffer.write(samples.pack("v*"))
      in_buffer.seek(0)

      in_buffer
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
