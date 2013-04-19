class CreateSongs < ActiveRecord::Migration

  def change
    create_table :songs do |t|
      t.string     :file_path,  null: false
      t.string     :title,      null: false
      t.integer    :length,     null: false
      t.integer    :sort_order, null: false
      t.references :show
      t.timestamps
    end
  end

end
