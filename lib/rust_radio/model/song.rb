# frozen_string_literal: true

require 'flacinfo'
require 'pathname'
require 'rust_radio/flac_details'

module RustRadio
  # A song, part of a show
  class Song < ActiveRecord::Base
    belongs_to :show

    validates_uniqueness_of :sort_order, scope: :show_id
    validates :title, :file_path, presence: true
    validate :file_path_in_show_folder

    # Runs before the other callbacks, so a refused removal changes nothing.
    before_destroy :ensure_removable, prepend: true
    after_destroy :follow_removal

    def full_file_path
      File.join(show.folder_path, file_path)
    end

    def stream_title
      song_info = info
      "#{song_info[:title]} (#{song_info[:album]})"
    end

    def info
      flac = FlacInfo.new(full_file_path)
      {
        title: flac.tags['TITLE'],
        artist: flac.tags['ARTIST'],
        album: flac.tags['ALBUM']
      }
    end

    # Sets the file to +path+, relative to the show folder or absolute inside
    # it, and the length to the new file's if it can be read. Returns false
    # with the reason in #errors.
    def change_file_path(path)
      self.file_path = path_from_folder(path.strip)
      read_length
      transaction { save && show.update_length! }
    end

    private

    # "./a.flac", "disc1/../a.flac" and the full path all become "a.flac". A
    # path outside the folder starts with "..", which the validation refuses.
    def path_from_folder(path)
      return path if path.empty? # left for the presence validation

      Pathname.new(File.expand_path(path, show.folder_path)).relative_path_from(show.folder_path).to_s
    end

    def read_length
      details = FlacDetails.new(show.folder_path, file_path)
      self.length = details.length if details.readable? && details.length
    end

    # The path is joined to the show folder, so it's relative and must not climb out with "..".
    def file_path_in_show_folder
      return unless file_path
      return unless File.absolute_path?(file_path) || Pathname.new(file_path).cleanpath.each_filename.first == '..'

      errors.add(:file_path, 'must be inside the show folder')
    end

    def show_song_ids
      Song.where(show_id:).order(:sort_order).ids
    end

    def ensure_removable
      ids = show_song_ids
      reason = if ids.size <= 1 then 'A show needs at least one song; delete the show instead.'
               elsif show.playing? then "Can't remove a song of the show that is playing while the radio is online."
               end
      if reason
        errors.add(:base, reason)
        throw :abort
      end
      @removed_index = ids.index(id)
    end

    # PlaylistEntry#current_song is an index into the show's songs, so the
    # entries that were past the removed song move back one. One that was at
    # the removed last song starts the show over.
    def follow_removal
      entries = show.playlist_entries
      entries.where('current_song > ?', @removed_index).update_all('current_song = current_song - 1')
      entries.where(current_song: show_song_ids.size..).update_all(current_song: 0)
      show.update_length!
    end
  end
end
