# frozen_string_literal: true

require 'acts_as_list'

module RustRadio
  # An entry in the playlist
  class PlaylistEntry < ActiveRecord::Base
    acts_as_list scope: :playlist

    belongs_to :playlist
    belongs_to :show

    include RustRadio::DragDrop

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
  end
end
