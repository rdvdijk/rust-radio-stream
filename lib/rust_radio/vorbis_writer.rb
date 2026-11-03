# frozen_string_literal: true

module RustRadio
  # Writes Ogg/Vorbis audio
  class VorbisWriter < Writer
    def initialize(config)
      super(config, 'vorbis')

      @encoder = VorbisEncoder.new(config)
    end

    def update(song)
      @encoder.start_stream(song.stream_title) do |data|
        shout(data)
      end
    end

    def write(samples)
      stream_vorbis(samples)
    end

    def close
      @encoder.close do |data|
        shout(data)
      end
      super
    end

    private

    # Convert the given samples to Vorbis data and stream it.
    def stream_vorbis(samples)
      @encoder.encode(samples) do |data|
        shout(data)
      end
    end
  end
end
