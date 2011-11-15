module RustRadio
  class Transcoder
    def initialize(reader, writer)
      @reader = reader
      @writer = writer
    end

    def transcode(song)
      @reader.update(song)
      @writer.update(song)

      @reader.read do |data|
        @writer.write data
      end
    end
  end
end
