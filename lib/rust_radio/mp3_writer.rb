# frozen_string_literal: true

module RustRadio
  # Writes MP3 audio
  class MP3Writer < Writer
    def initialize(config)
      super(config, 'mp3')

      @encoder = MP3Encoder.new(config)
    end

    def write(samples)
      stream_mp3(samples)
    end

    private

    # Convert the given interleaved samples to MP3 data and stream it.
    def stream_mp3(samples)
      @encoder.encode(samples) do |data|
        shout(data)
      end
    end
  end
end
