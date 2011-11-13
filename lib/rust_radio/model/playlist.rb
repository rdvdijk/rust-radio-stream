class RustRadio::Playlist
  include DataMapper::Resource
  storage_names[:default] = 'playlists'

  class Entry
    include DataMapper::Resource
    storage_names[:default] = 'playlist_entries'

    belongs_to :playlist
    belongs_to :show

    property :id,           Serial
    property :current_song, Integer, default: 0, required: true

    property :created_at, DateTime
    property :updated_at, DateTime

    is :list, :scope => :playlist_id

    def current_song_path
      show.get(current_song).full_file_path
    end

    def current_song_title
      show.get(current_song).title
    end

    def next
      next_index = (current_song+1) % show.songs.length
      self.current_song = next_index
      save
    end

    def first?
      position == 1
    end

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
        puts
        puts "move #{self.id} (#{self.position}) below #{other.id} (#{other.position})"
        puts
        result = self.move(:below => other)
        puts "ok? #{result}"
        self.save
        self.reload
      end
    end

    def reset!
      self.current_song = 0
      save
    end
  end

  has n, :entries, order: [ :position.asc ]
  has n, :shows, through: :entries

  property :id,     Serial
  property :name,   String, required: true
  property :online, Boolean

  property :created_at, DateTime
  property :updated_at, DateTime

  def play
    online!
    while true
      entry = entries.first
      yield entry.current_song_path
      entry.next

      if entry.current_song == 0
        entry.move(:bottom)
        reload
      end
    end
  ensure
    offline!
  end

  def first
    entries.first
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
