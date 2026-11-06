# frozen_string_literal: true

module RustRadio
  # A show that can be played on the radio
  class Show < ActiveRecord::Base
    # Runs before the songs are deleted, so a refused destroy changes nothing.
    before_destroy :ensure_not_on_playlist, prepend: true

    has_many :songs, -> { order('sort_order ASC') }, dependent: :delete_all
    has_many :playlist_entries

    validates_uniqueness_of :folder_path

    # Names of the playlists this show is on.
    def playlist_names
      Playlist.joins(:entries).where(playlist_entries: { show_id: id }).distinct.pluck(:name)
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
