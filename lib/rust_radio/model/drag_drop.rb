# frozen_string_literal: true

module RustRadio
  # Drag-drop module used in the playlist UI
  module DragDrop
    # Move to top if offline, move to second place if online.
    def move_to_top
      return if first?

      if playlist.online? && !first?
        insert_at(2)
      else
        playlist.first.reset!
        super
      end
    end

    # Move below the given other entry.
    # Reset the current song if moving the first entry.
    # Don't move the first entry when online.
    def move_below(other)
      new_position = other.position
      new_position += 1 if position >= other.position

      if playlist.online?
        if first?
          # can't move the first entry while playing
        else
          insert_at(new_position)
        end
      else
        reset! if first?
        insert_at(new_position)
        save
        reload
      end
    end

    # Move to +new_position+ (1-based, clamped to the playlist). While online,
    # the playing (first) entry doesn't move and nothing can take its place.
    # Offline, the entry that loses first place starts over at its first song.
    # Returns true if the entry moved; on a refusal, the reason is in #errors.
    def move_to(new_position)
      reload
      unless removable? # also reloads the playlist
        errors.add(:base, "Can't move the show that is playing while the radio is online.")
        return false
      end

      first_free = playlist.online? ? 2 : 1
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
  end
end
