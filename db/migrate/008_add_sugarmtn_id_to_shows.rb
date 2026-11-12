# frozen_string_literal: true

# Add sugarmtn.org show identifier to shows table, to link to
# https://sugarmtn.org/sm_show.php?show=<sugarmtn_id>
class AddSugarmtnIdToShows < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :sugarmtn_id, :string, limit: 9
  end
end
