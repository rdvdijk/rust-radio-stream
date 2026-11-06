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
      reason = move_refusal(new_position)
      if reason
        errors.add(:base, reason)
        return false
      end

      last = playlist.entries.size
      return false if last < first_free_position

      new_position = new_position.clamp(first_free_position, last)
      return false if new_position == position

      insert_and_reset(new_position)
      true
    end

    def reset!
      self.current_song = 0
      save
    end

    private

    # Checks the database for the online state: removable? reloads the playlist.
    def move_refusal(new_position)
      return "Can't move the show that is playing while the radio is online." unless removable?
      return unless new_position < first_free_position && position == first_free_position

      'The show that is playing stays at the top while the radio is online.'
    end

    # The playing entry keeps first place while online.
    def first_free_position
      playlist.online? ? 2 : 1
    end

    def insert_and_reset(new_position)
      displaced_first = playlist.first if first? || new_position == 1
      insert_at(new_position)
      displaced_first.reload.reset! if displaced_first && !playlist.online?
    end
  end
end
