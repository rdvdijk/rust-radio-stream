require 'icanhasaudio'

module RustRadio
  class MP3Encoder
    def initialize(config)
      encoder = Audio::MPEG::Encoder.new
      encoder.vbr_type = Audio::MPEG::Encoder::VBR_OFF
      encoder.bitrate = config["mp3"]["bitrate"]
      encoder.init
      @encoder = encoder
    end

    def encode(in_buffer, &block)
      @encoder.encode_io(in_buffer, &block)
    end

    def flush(&block)
      @encoder.flush_io(&block)
    end
  end
end
