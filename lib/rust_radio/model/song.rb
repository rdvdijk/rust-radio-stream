require 'flacinfo'

module RustRadio
  class Song < ActiveRecord::Base

    belongs_to :show

    validates_uniqueness_of :sort_order, scope: :show_id

    def full_file_path
      File.join(show.folder_path, file_path)
    end

    def stream_title
      song_info = info
      "#{song_info[:title]} (#{song_info[:album]})"
    end

    def info
      flac = FlacInfo.new(full_file_path)
      {
        title: flac.tags["TITLE"],
        artist: flac.tags["ARTIST"],
        album: flac.tags["ALBUM"]
      }
    end

  end
end
