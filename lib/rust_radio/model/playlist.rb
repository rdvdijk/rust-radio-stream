# frozen_string_literal: true

module RustRadio
  # Playlist class, contains the main show playing loop
  class Playlist < ActiveRecord::Base
    has_many :entries, -> { order('position ASC') }, class_name: 'PlaylistEntry'
    has_many :shows, through: :entries

    def play
      online!
      loop do
        entry = first
        entry.mark_start_of_song!
        yield entry.song_to_play
        entry.next

        if next_show?
          entry.move_to_bottom
          reload
        end
      end
    ensure
      offline!
    end

    def first
      entries.first
    end

    # Put the entries in a random order. While online, the playing (first)
    # entry stays first. Offline, the old first entry starts over if it moves.
    def shuffle!
      transaction do
        reload
        old_first = first
        fixed = online? ? entries.first(1) : []
        order = fixed + (entries.to_a - fixed).shuffle
        order.each_with_index { |entry, index| entry.update_column(:position, index + 1) }
        old_first.reset! if old_first && !online? && order.first != old_first
      end
      reload
    end

    def current_show_title
      first.show_title
    end

    def next_show?
      first.starting?
    end

    private

    def online!
      self.online = true
      save
      reload
    end

    def offline!
      self.online = false
      save
      reload
    end
  end
end
