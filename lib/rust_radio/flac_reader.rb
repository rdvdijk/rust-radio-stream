require 'ruby-audio'

module RustRadio
  class FlacReader
    def update(song)
      @file_path = song.full_file_path
    end

    def read
      RubyAudio::Sound.open(@file_path) do |sound|
        while buffer = sound.read(:short, 64*1024) and buffer.real_size > 0
          yield buffer
        end
      end
    end
  end
end

