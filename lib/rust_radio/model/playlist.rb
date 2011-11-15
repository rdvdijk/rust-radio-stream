class RustRadio::Playlist
  include DataMapper::Resource
  storage_names[:default] = 'playlists'

  class Entry
    include DataMapper::Resource
    include RustRadio::DragDrop
    storage_names[:default] = 'playlist_entries'

    belongs_to :playlist
    belongs_to :show

    property :id,           Serial
    property :current_song, Integer, default: 0, required: true

    property :created_at, DateTime
    property :updated_at, DateTime

    is :list, :scope => :playlist_id

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
      next_index = (current_song+1) % show.songs.length
      self.current_song = next_index
      save
    end

    def first?
      position == 1
    end

    def starting?
      current_song == 0
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
      entry = first
      yield entry.song_to_play
      entry.next

      if next_show?
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
