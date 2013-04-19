class CreateShows < ActiveRecord::Migration

  def change
    create_table :shows do |t|
      t.string    :folder_path
      t.string    :artist
      t.date      :date
      t.string    :title
      t.text      :info_file
      t.string    :setlist_identifier
      t.date_time :last_played_at
      t.timestamps
    end
  end

end
