require 'lame'

module RustRadio
  class MP3Encoder
    def initialize(config)
      encoder = LAME::Encoder.new
      encoder.configure do |encoder_config|
        encoder_config.bitrate = config["mp3"]["bitrate"]
        encoder_config.quality = 2
      end
      @encoder = encoder
    end

    def encode(in_buffer, &block)
      #input = buffer_to_samples(in_buffer).flatten.map(&:to_i)
      @encoder.encode_interleaved_short(in_buffer, &block)
    end

    def flush(&block)
      @encoder.flush(&block)
    end
  end
end
