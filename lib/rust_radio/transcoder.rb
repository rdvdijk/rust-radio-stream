module RustRadio
  class Transcoder

    def initialize(reader, writers)
      @reader  = reader
      @writers = writers
    end

    def transcode(song)
      @reader.update(song)

      @writers.each do |writer|
        writer.update(song)
      end

      @reader.read do |buffer|
        @writers.each do |writer|
          writer.write buffer
        end
        @writers.first.sync
      end
    end

    def close
      @writers.each do |writer|
        writer.close
      end
    end

  end
end
