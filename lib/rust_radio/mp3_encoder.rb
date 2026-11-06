# frozen_string_literal: true

require 'lame'

module RustRadio
  # Encodes audio to MP3
  class MP3Encoder
    def initialize(config)
      encoder = LAME::Encoder.new
      encoder.configure do |encoder_config|
        encoder_config.bitrate = config['mp3']['bitrate']
        encoder_config.quality = 2
      end
      @encoder = encoder
    end

    def encode(samples, &)
      @encoder.encode_interleaved_short(samples, &)
    end

    def flush(&)
      @encoder.flush(&)
    end
  end
end
