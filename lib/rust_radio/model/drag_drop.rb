module RustRadio
  module DragDrop
    # Move to top if offline, move to second place if online.
    def move_to_top
      unless first?
        if playlist.online? and !first?
          move(:below => playlist.first)
        else
          playlist.first.reset!
          move(:top)
        end
      end
    end

    # Move below the given other entry.
    # Reset the current song if moving the first entry.
    # Don't move the first entry when online.
    def move_below(other)
      if playlist.online?
        if first?
          # can't move the first entry while playing
        else
          move(:below => other)
        end
      else
        if first?
          reset!
        end
        result = self.move(:below => other)
        self.save
        self.reload
      end
    end

    def reset!
      self.current_song = 0
      save
    end
  end
end
