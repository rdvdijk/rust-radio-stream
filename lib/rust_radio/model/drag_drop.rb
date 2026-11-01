# frozen_string_literal: true
module RustRadio
  module DragDrop
    # Move to top if offline, move to second place if online.
    def move_to_top
      return if first?

      if playlist.online? and !first?
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

    def reset!
      self.current_song = 0
      save
    end
  end
end
