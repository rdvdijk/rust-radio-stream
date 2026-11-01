# frozen_string_literal: true

require 'ruby-audio'

module RustRadio
  # Reader for FLAC files
  class FlacReader
    def update(song)
      @file_path = song.full_file_path
    end

    def read
      RubyAudio::Sound.open(@file_path) do |sound|
        while (buffer = sound.read(:short, 64 * 1024)) && buffer.real_size.positive?
          yield buffer
        end
      end
    end
  end
end
