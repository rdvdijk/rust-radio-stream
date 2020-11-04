module RustRadio
  class VorbisEncoder

    def initialize(config)
      @io = StringIO.new
      @sound = RubyAudio::Sound.open(@io, 'w', sound_info)
    end

    def encode(in_buffer, &block)
      @io.string = "" # reset output buffer

      @sound.write(in_buffer)

      yield @io.string
    end

    def close
      @sound.close unless @sound.closed?
    end

    private

    def sound_info
      @sound_info ||= RubyAudio::SoundInfo.new(
        channels: 2,
        samplerate: 44100,
        format: RubyAudio::FORMAT_OGG|RubyAudio::FORMAT_VORBIS
      )
    end
  end
end
