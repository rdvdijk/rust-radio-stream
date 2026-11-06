# frozen_string_literal: true

module RustRadio
  # Reordering a playlist entry, used by the web UI and the playlist CLI.
  # All moves go through #move_to, which holds the playlist rules.
  module DragDrop
    # Move to the top, or to second place while online.
    def move_to_top
      move_to(1)
    end

    # Move below the given other entry.
    def move_below(other)
      move_to(position >= other.position ? other.position + 1 : other.position)
    end

    # Move to +new_position+ (1-based, clamped to the playlist). While online,
    # the playing (first) entry doesn't move and nothing can take its place.
    # Offline, the entry that loses first place starts over at its first song.
    # Returns true if the entry moved; on a refusal, the reason is in #errors.
    def move_to(new_position)
      reload
      return refuse("Can't move the show that is playing while the radio is online.") unless removable?

      first_free = playlist.online? ? 2 : 1 # removable? reloaded the playlist
      if new_position < first_free && position == first_free
        return refuse('The show that is playing stays at the top while the radio is online.')
      end

      last = playlist.entries.size
      return false if last < first_free

      new_position = new_position.clamp(first_free, last)
      return false if new_position == position

      displaced_first = playlist.first if first? || new_position == 1
      insert_at(new_position)
      displaced_first&.reload&.reset! unless playlist.online?
      true
    end

    def reset!
      self.current_song = 0
      save
    end

    private

    def refuse(reason)
      errors.add(:base, reason)
      false
    end
  end
end
