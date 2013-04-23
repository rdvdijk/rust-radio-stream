class AddSongStartedAtToPlaylistEntry < ActiveRecord::Migration

  def change
    add_column :playlist_entries, :song_started_at, :datetime
  end

end
