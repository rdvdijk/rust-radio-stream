module RustRadio
  class Transcoder

    def initialize(reader, writers)
      @reader  = reader
      @writers = writers
      @synchronization_time = Time.now.to_f
    end

    def transcode(song)
      @reader.update(song)

      @writers.each do |writer|
        writer.update(song)
      end

      @reader.read do |buffer|
        wait until synchronize?

        @writers.each do |writer|
          writer.write buffer
        end

        set_synchronization_delay!
      end
    end

    def close
      @writers.each do |writer|
        writer.close
      end
    end

    private

    def set_synchronization_delay!
      @synchronization_time = Time.now.to_f + shortest_delay/1000.0
    end

    def shortest_delay
      @writers.map(&:delay).min
    end

    def wait
      sleep 0.01
    end

    def synchronize?
      Time.now.to_f >= @synchronization_time
    end

  end
end
