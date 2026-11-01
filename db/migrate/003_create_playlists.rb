# frozen_string_literal: true
class CreatePlaylists < ActiveRecord::Migration[8.1]
  def change
    create_table :playlists do |t|
      t.string :name, null: false
      t.boolean :online
      t.timestamps
    end
  end
end
