# frozen_string_literal: true

# Add notes to shows table, e.g. why a show was added
class AddNotesToShows < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :notes, :text
  end
end
