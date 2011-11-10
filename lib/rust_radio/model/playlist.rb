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

    property :sort_order,   Integer, required: true, unique: true
    property :created_at, DateTime
    property :updated_at, DateTime

    # return the next song for this entry
    def current_song_path
      show.get(current_song)
    end

    def next
      next_index = (current_song+1) % show.songs.length
      self.current_song = next_index
      save
    end
  end

  has n, :entries, order: [ :sort_order.asc ]
  has n, :shows, through: :entries

  property :id,   Serial
  property :name, String, required: true

  property :created_at, DateTime
  property :updated_at, DateTime

  def play
    while true
      entry = entries.first
      yield entry.current_song_path
      entry.next

      if entry.current_song == 0
        entry.sort_order = entries.max(:sort_order) + 1
        entry.save
        reload
        # update all sort_order values -= 1 ..
      end
    end
  end
end
