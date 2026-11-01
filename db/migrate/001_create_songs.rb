# frozen_string_literal: true
class CreateSongs < ActiveRecord::Migration[8.1]
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
