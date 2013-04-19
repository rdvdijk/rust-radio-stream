require 'flacinfo'

module RustRadio
  class Song < ActiveRecord::Base

    belongs_to :show

    validates_uniqueness_of :sort_order, :scope => :show_id

    def full_file_path
      File.join(show.folder_path, file_path)
    end

    def stream_title
      flac = FlacInfo.new(full_file_path)
      title  = flac.tags["TITLE"]
      album = flac.tags["ALBUM"]

      "#{title} (#{album})"
    end
  end
end
