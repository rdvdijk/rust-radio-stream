# frozen_string_literal: true

require 'flacinfo'

module RustRadio
  # The tags and stream info of one FLAC file, for showing before a show is
  # added. Never raises: an unreadable file gets a warning instead.
  class FlacDetails
    # Tags that are usually the same for all files of a show.
    COMMON_TAGS = %w[ARTIST ALBUM DATE].freeze
    SAMPLE_RATE = 44_100 # the only sample rate ShowAdder accepts

    attr_reader :file, :length, :warnings

    def initialize(folder_path, file)
      @file = file
      @tags = {}
      @warnings = []
      @readable = false
      path = File.join(folder_path, file)
      read(path)
      @readable = true
    rescue StandardError => e
      @warnings << "Can't read FLAC file: #{e.message.sub(path, file)}"
    end

    def readable?
      @readable
    end

    # Tag value by name, case-insensitive.
    def [](tag)
      @tags[tag.upcase]
    end

    def title
      self['TITLE']
    end

    # "3" or "3/14" → 3; nil if not set.
    def track_number
      number = self['TRACKNUMBER'].to_s[/\d+/]
      number&.to_i
    end

    private

    def read(path)
      info = FlacInfo.new(path)
      read_tags(info)
      samplerate = info.streaminfo['samplerate'].to_i
      @length = info.streaminfo['total_samples'] / samplerate.to_f * 1000 if samplerate.positive?
      check(info, samplerate)
    end

    def read_tags(info)
      info.tags.each { |name, value| @tags[name.to_s.upcase] = clean(value) if value.is_a?(String) }
    end

    # ShowAdder refuses a file with any warning.
    def check(info, samplerate)
      @warnings << 'TITLE tag not set' unless info.tags['TITLE']
      @warnings << "Sample rate is #{samplerate} Hz, must be #{SAMPLE_RATE}" unless samplerate == SAMPLE_RATE
    end

    # flacinfo returns raw bytes; tags are UTF-8 by the Vorbis comment spec.
    def clean(value)
      value.dup.force_encoding(Encoding::UTF_8).scrub('?').strip
    end
  end
end
