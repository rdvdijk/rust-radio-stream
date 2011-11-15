class RustRadio::Show
  include DataMapper::Resource
  storage_names[:default] = 'shows'

  has n, :songs, :order => [ :sort_order.asc ]

  property :id,           Serial
  property :folder_path,  String, length: 255, unique: true
  property :artist,       String
  property :date,         Date
  property :title,        String
  property :info_file,    Text
  property :setlist_identifier,   String

  property :last_played_at, DateTime
  property :created_at,     DateTime
  property :updated_at,     DateTime

  def length
    songs.sum(:length)
  end

  def get(index)
    songs[index]
  end

  def short_title
    "#{title.match(/^([^,]*)/)} #{date.year}"
  end

  def long_title
    "#{artist} @ #{title}. #{date}"
  end
end
