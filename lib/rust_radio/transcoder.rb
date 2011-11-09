module RustRadio
  class Transcoder
    def initialize(reader, writer)
      @reader = reader
      @writer = writer
    end

    def transcode(file_path)
      @reader.update(file_path)
      @writer.update(file_path)

      @reader.read do |data|
        @writer.write data
      end
    end
  end
end
