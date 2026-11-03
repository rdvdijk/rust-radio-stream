# frozen_string_literal: true

require 'sndfile'
require 'stringio'

module RustRadio
  # Encodes audio to Ogg/Vorbis.
  class VorbisEncoder
    def initialize(_config)
      @io = StringIO.new(+''.b)
    end

    def start_stream(title, &)
      close(&)
      @sound = SndFile.open(@io, :write, format: :ogg, subtype: :vorbis,
                                         samplerate: 44_100, channels: 2,
                                         strings: { title: title })
    end

    def encode(samples, &)
      @sound.write(samples, type: :short)
      flush(&)
    end

    def close(&)
      return if @sound.nil? || @sound.closed?

      @sound.close
      flush(&)
    end

    private

    def flush
      data = @io.string
      @io.string = +''.b # reset output buffer
      yield data if block_given? && !data.empty?
    end
  end
end
