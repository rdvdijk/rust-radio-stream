class RustRadio::Song
  include DataMapper::Resource
  storage_names[:default] = 'songs'

  belongs_to :show

  property :id,         Serial
  property :file_path,  String,  required: true
  property :title,      String,  required: true
  property :length,     Integer, required: true

  property :sort_order, Integer, required: true #, unique: [:show_id, :sort_order]
  property :created_at, DateTime
  property :updated_at, DateTime

  validates_uniqueness_of :sort_order, :scope => :show_id

  def full_file_path
    File.join(show.folder_path, file_path)
  end
end
