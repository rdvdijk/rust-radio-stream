class RustRadio::Playlist
  include DataMapper::Resource
  storage_names[:default] = 'playlists'

  class Entry
    include DataMapper::Resource
    storage_names[:default] = 'playlist_entries'

    belongs_to :playlist
    belongs_to :show
    property :id,           Serial
    property :sort_order,   Integer
    property :current_song, Integer, :default => 0

    def next
      song = show.get(current_song)
      @current_song = (@current_song+1) % show.songs.length
      save
      song
    end
  end

  has n, :entries, :order => [ :sort_order.asc ]
  has n, :shows, :through => :entries

  property :id,   Serial
  property :name, String, :required => true

  def next_song
    entry = entries.first
    entry.next
  end
end
