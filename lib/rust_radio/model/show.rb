module RustRadio
  class Show < ActiveRecord::Base

    has_many :songs, :order => "sort_order"

    validates_uniqueness_of :folder_path

    def length
      songs.sum(:length)
    end

    def get(index)
      songs[index]
    end

    def short_title
      "#{title.match(/^([^,]*)/)} #{date.year}"
    end

    def long_title
      "#{date} #{artist} @ #{title}"
    end
  end
end
