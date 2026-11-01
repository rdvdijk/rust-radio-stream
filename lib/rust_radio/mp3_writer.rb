# frozen_string_literal: true

module RustRadio
  class MP3Writer < Writer
    def initialize(config)
      super(config, 'mp3')

      @encoder = MP3Encoder.new(config)
    end

    def write(buffer)
      stream_mp3(buffer)
    end

    private

    # Convert the given samples to MP3 data and stream it.
    def stream_mp3(buffer)
      samples = buffer_to_samples(buffer)

      @encoder.encode(samples) do |data|
        shout(data)
      end
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
