# frozen_string_literal: true

module RustRadio
  # A show that can be played on the radio
  class Show < ActiveRecord::Base
    # Runs before the songs are deleted, so a refused destroy changes nothing.
    before_destroy :ensure_not_on_playlist, prepend: true

    has_many :songs, -> { order('sort_order ASC') }, dependent: :delete_all
    has_many :playlist_entries
    has_many :playlists, through: :playlist_entries

    # Stored as an absolute path, also in lookups, so "./show", "show/" and
    # "/music/show" are the same folder to the uniqueness check and find_by.
    normalizes :folder_path, with: ->(path) { File.expand_path(path) }
    validates_uniqueness_of :folder_path

    scope :in_year, ->(year) { where(date: Date.new(year).all_year) }

    def playlist_names
      playlists.distinct.pluck(:name)
    end

    # "Default, Other", or "none".
    def playlist_summary
      playlist_names.join(', ').presence || 'none'
    end

    def get(index)
      songs[index]
    end

    def short_title
      "#{city_state.match(/^([^,]*)/)} #{date.year}"
    end

    def long_title
      "#{date} #{artist} @ #{city_state}"
    end

    private

    def ensure_not_on_playlist
      names = playlist_names
      return if names.empty?

      errors.add(:base, "Show is on playlist #{names.map { |name| "'#{name}'" }.join(', ')}; remove it there first.")
      throw :abort
    end
  end
end
