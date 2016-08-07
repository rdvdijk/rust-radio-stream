class CreatePlaylistEntries < ActiveRecord::Migration

  def change
    create_table :playlist_entries do |t|
      t.integer :current_song, default: 0, null: false
      t.integer :position, default: 0, null: false
      t.references :playlist
      t.references :show
      t.timestamps
    end
  end

end
