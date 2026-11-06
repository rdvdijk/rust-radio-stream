# frozen_string_literal: true

module RustRadio
  # The label/value rows of the show info pop-up in the playlist UI, in the
  # format TerminalUI#draw_popup takes.
  module ShowInfo
    module_function

    def rows(show)
      [['Notes', show.notes], ['Venue', show.venue], ['City', show.city_state], ['Festival', show.festival],
       ['Length', format_length(show.length.to_i)], ['Songs', show.songs.count.to_s],
       ['Folder', show.folder_path, :value, :start], ['Playlists', show.playlist_summary],
       ['Last played', show.last_played_at&.strftime('%Y-%m-%d %H:%M')],
       ['Added', show.created_at&.strftime('%Y-%m-%d')]].reject { |_label, value| value.blank? }
    end

    # Extra rows for a show on the playlist: its position, and for the first
    # entry the song that is playing (or plays next, while offline).
    def entry_rows(entry, entry_count, online)
      rows = [['Position', "#{entry.position} of #{entry_count}"]]
      return rows unless entry.position == 1

      song = entry.song_to_play
      rows << [online ? 'Now playing' : 'Next song',
               "#{entry.current_song + 1}/#{entry.show.songs.size} #{song&.title}", (:playing if online)]
    end

    # "8h 40m"
    def format_length(milliseconds)
      minutes = (milliseconds / 60_000).round
      "#{minutes / 60}h #{(minutes % 60).to_s.rjust(2, '0')}m"
    end
  end
end
