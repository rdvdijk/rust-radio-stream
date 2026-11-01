require 'lame'

module RustRadio
  class MP3Encoder
    def initialize(config)
      encoder = LAME::Encoder.new
      encoder.configure do |encoder_config|
        encoder_config.bitrate = config['mp3']['bitrate']
        encoder_config.quality = 2
      end
      @encoder = encoder
    end

    def encode(samples, &block)
      @encoder.encode_interleaved_short(samples, &block)
    end

    def flush(&block)
      @encoder.flush(&block)
    end
  end
end
