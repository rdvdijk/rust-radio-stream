class RustRadio::Song
  include DataMapper::Resource
  storage_names[:default] = 'songs'

  belongs_to :show

  property :id,         Serial
  property :file_path,  String,  :required => true
  property :title,      String,  :required => true
  property :length,     Integer, :required => true

  property :sort_order, Integer
  property :created_at, DateTime
  property :updated_at, DateTime

  def full_file_path
    # show + song path
  end
end
