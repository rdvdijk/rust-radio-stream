require 'icanhasaudio'

module RustRadio
  class Encoder

    def initialize(config)
      writer = Audio::MPEG::Encoder.new
      writer.vbr_type = Audio::MPEG::Encoder::VBR_OFF
      writer.bitrate = config["bitrate"]
      writer.init
      @encoder = writer
    end

    def encode(in_buffer, &block)
      @encoder.encode_io(in_buffer, &block)
    end

    def flush(&block)
      @encoder.flush_io(&block)
    end

  end
end
