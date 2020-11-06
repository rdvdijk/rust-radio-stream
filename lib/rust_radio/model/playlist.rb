module RustRadio
  class Playlist < ActiveRecord::Base

    has_many :entries, -> { order("position ASC") }, class_name: "PlaylistEntry"
    has_many :shows, through: :entries

    def play
      online!
      while true
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
