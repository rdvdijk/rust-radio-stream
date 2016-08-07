class CreatePlaylists < ActiveRecord::Migration

  def change
    create_table :playlists do |t|
      t.string :name, null: false
      t.boolean :online
      t.timestamps
    end
  end

end
