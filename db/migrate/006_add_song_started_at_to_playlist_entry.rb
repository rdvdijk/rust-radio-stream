class AddSongStartedAtToPlaylistEntry < ActiveRecord::Migration[8.1]
  def change
    add_column :playlist_entries, :song_started_at, :datetime
  end
end
