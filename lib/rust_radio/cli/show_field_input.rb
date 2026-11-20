# frozen_string_literal: true

require 'rust_radio/cli/text_input'
require 'rust_radio/cli/folder_completer'

module RustRadio
  # A TextInput pop-up that edits one field of a show and saves it. The host
  # UI sends it every key while it's open, and shows #message, if any.
  class ShowFieldInput
    LABELS = { notes: 'Notes', setlist_identifier: 'Setlist ID', folder_path: 'Folder' }.freeze
    # The show's date and its number on that day, as sugarmtn.org numbers them.
    SETLIST_IDENTIFIER = /\A\d{9}\z/
    SETLIST_IDENTIFIER_HINT = 'A setlist ID is the date and 0, 1 (early) or 2 (late), for example 197810220.'
    FOLDER_HELP = [%w[Tab complete], *TextInput::HELP].freeze
    COMPLETE_KEYS = { 9 => 1, "\t" => 1, Curses::KEY_BTAB => -1 }.freeze # Shift-Tab cycles back

    attr_reader :message

    def initialize(show, field)
      @show = show
      @field = field
      @text_input = TextInput.new(" #{LABELS[field]}: #{show.long_title} ", show[field],
                                  help: field == :folder_path ? FOLDER_HELP : TextInput::HELP)
      @completer = FolderCompleter.new if field == :folder_path
    end

    # Returns :close when the input is done. An invalid value keeps it open,
    # so it can be corrected. Raises ActiveRecord errors from saving.
    def handle_key(key)
      return complete(COMPLETE_KEYS[key]) if @completer && COMPLETE_KEYS.key?(key)

      case @text_input.handle_key(key)
      when :cancel then :close
      when :save then save
      end
    end

    def draw(screen)
      @text_input.draw(screen)
    end

    private

    def save
      value = @text_input.text.presence
      @message = invalid_message(value)
      return if @message

      unless @show.update(@field => value)
        @message = [@show.errors.full_messages.join(' '), :error]
        @show.restore_attributes
        return
      end

      note = missing_songs_note
      @message = ["#{LABELS[@field]} saved for #{@show.long_title}#{note}", note.empty? ? :playing : :error]
      :close
    end

    # Every Tab sets a message, so the status line never shows an old one.
    def complete(step)
      completed = @completer.complete(@text_input.text, step)
      @text_input.text = completed if completed
      @message = completion_message
      nil
    end

    def completion_message
      count = @completer.matches.size
      if count.zero? then ['No folder matches', :error]
      elsif count == 1 then ['One folder matches', :label]
      elsif @completer.index then ["Folder #{@completer.index + 1} of #{count}, Tab for the next", :label]
      else ["#{count} folders match, Tab to go through them", :label]
      end
    end

    def invalid_message(value)
      case @field
      when :setlist_identifier
        [SETLIST_IDENTIFIER_HINT, :error] if value && !value.match?(SETLIST_IDENTIFIER)
      when :folder_path
        ["Folder not found: #{value}", :error] unless value && File.directory?(File.expand_path(value))
      end
    end

    # The songs' file paths are relative to the folder, so a renamed folder
    # can still be missing files that were renamed too.
    def missing_songs_note
      return '' unless @field == :folder_path

      missing = @show.songs.count { |song| !File.file?(File.join(@show.folder_path, song.file_path)) }
      missing.positive? ? ", but #{missing} of #{@show.songs.size} song files are not in it" : ''
    end
  end
end
