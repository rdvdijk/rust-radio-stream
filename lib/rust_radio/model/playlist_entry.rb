# frozen_string_literal: true

require 'acts_as_list'

module RustRadio
  # An entry in the playlist
  class PlaylistEntry < ActiveRecord::Base
    acts_as_list scope: :playlist

    belongs_to :playlist
    belongs_to :show

    include RustRadio::DragDrop

    # Runs before acts_as_list's callbacks, so a refused removal changes nothing.
    before_destroy :ensure_removable, prepend: true

    # The entry that is playing (the first one, while the radio is online)
    # can't be removed. Checks the database, as the radio runs in another process.
    def removable?
      playlist.reload
      !(playlist.online? && playlist.first == self)
    end

    def song_to_play
      show.get(current_song)
    end

    def current_song_title
      song_to_play.title
    end

    def show_title
      show.long_title
    end

    def next
      next_index = (current_song + 1) % show.songs.length
      self.current_song = next_index
      save!
    end

    def starting?
      current_song.zero?
    end

    def mark_start_of_song!
      self.song_started_at = Time.now
      save!
    end

    private

    def ensure_removable
      return if removable?

      errors.add(:base, "Can't remove the show that is playing while the radio is online.")
      throw :abort
    end
  end
end
