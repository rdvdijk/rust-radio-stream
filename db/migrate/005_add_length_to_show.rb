class AddLengthToShow < ActiveRecord::Migration

  def change
    add_column :shows, :length, :integer
  end

end
