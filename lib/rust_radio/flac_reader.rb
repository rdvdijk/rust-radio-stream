# frozen_string_literal: true

require 'sndfile'

module RustRadio
  # Reader for FLAC files
  class FlacReader
    BUFFER_FRAMES = 64 * 1024

    def update(song)
      @file_path = song.full_file_path
    end

    def read(&)
      SndFile.open(@file_path) do |sound|
        sound.each_buffer(BUFFER_FRAMES, type: :short, &)
      end
    end
  end
end
