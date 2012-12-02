module RustRadio
  class IcecastWriter < Writer

    def initialize(config)
      super(config["icecast"])

      @encoder = VorbisEncoder.new(config)
    end

    def write(buffer)
      stream_vorbis(buffer)
    end

    def close
      @encoder.close
      super
    end

    private

    # Convert the given samples to Vorbis data and stream it.
    def stream_vorbis(in_buffer)
      @encoder.encode(in_buffer) do |data|
        shout(data)
      end
    end

  end
end
