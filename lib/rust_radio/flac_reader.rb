# frozen_string_literal: true

require 'sndfile'

module RustRadio
  # Reader for FLAC files
  class FlacReader
    BUFFER_FRAMES = 64 * 1024

    def update(song)
      @file_path = song.full_file_path
    end

    def read
      sound = open_file
      return unless sound

      begin
        while (samples = read_buffer(sound))
          yield samples
        end
      ensure
        close_file(sound)
      end
    end

    private

    def open_file
      SndFile.open(@file_path)
    rescue SndFile::SndFileError => e
      log_error('open', e)
      nil
    end

    # nil at the end of the file, and after a read error.
    def read_buffer(sound)
      samples = sound.read(BUFFER_FRAMES, type: :short)
      samples unless samples.empty?
    rescue SndFile::SndFileError => e
      log_error('read', e)
      nil
    end

    def close_file(sound)
      sound.close
    rescue SndFile::SndFileError => e
      log_error('close', e)
    end

    def log_error(action, error)
      RustRadio.logger.error("Can't #{action} #{@file_path}, skipping the rest of the song: " \
                             "#{error.class}: #{error.message}")
    end
  end
end
