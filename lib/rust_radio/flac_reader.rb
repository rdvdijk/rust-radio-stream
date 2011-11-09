require 'ruby-audio'

module RustRadio
  class FlacReader

    def update(file_path)
      @file_path = file_path
    end

    def read
      RubyAudio::Sound.open(@file_path) do |sound|
        while buf = sound.read(:short, 64*1024) and buf.real_size > 0
          samples = buffer_to_samples(buf)
          yield samples
        end
      end
    end

    private

    def buffer_to_samples(buffer)
      samples = []
      buffer.each do |left, right|
        samples << left << right
      end

      samples
    end
  end
end
