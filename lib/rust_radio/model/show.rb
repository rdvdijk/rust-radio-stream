# frozen_string_literal: true

module RustRadio
  # A show that can be played on the radio
  class Show < ActiveRecord::Base
    has_many :songs, -> { order('sort_order ASC') }

    validates_uniqueness_of :folder_path

    def get(index)
      songs[index]
    end

    def short_title
      "#{city_state.match(/^([^,]*)/)} #{date.year}"
    end

    def long_title
      "#{date} #{artist} @ #{city_state}"
    end
  end
end
