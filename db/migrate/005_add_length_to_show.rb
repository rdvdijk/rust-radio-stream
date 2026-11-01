# frozen_string_literal: true

class AddLengthToShow < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :length, :integer
  end
end
