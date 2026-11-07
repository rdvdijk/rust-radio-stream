# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'
require 'rust_radio/cli/text_input'

module RustRadio
  # A pop-up with the songs of a show, to fix a song's file or title, or to
  # remove a song from the show. The host UI sends it keys while it's open and
  # calls #draw at the end of its own drawing.
  class SongList
    HELP = [['↑/↓', 'select'], ['Enter/e', 'edit file', 'e'], %w[t title], %w[d remove], %w[Esc close]].freeze
    CONFIRM_HELP = [%w[y remove], ['any other key', 'cancel']].freeze
    EDIT_FILE_KEYS = [*TerminalUI::ENTER_KEYS, 'e', 'E'].freeze
    REMOVE_KEYS = ['d', 'D', Curses::KEY_DC].freeze
    LENGTH_WIDTH = 7 # "1:23:45"
    MISSING_MARK = '✗'
    PLAYING_MARK = '▶'

    # +playing_entry+: the playlist entry that is playing this show, if any;
    # its current song is marked.
    def initialize(show, playing_entry: nil)
      @show = show
      @playing_entry = playing_entry
      @cursor = 0
      @offset = 0
      load_songs
    end

    # Returns :close when the list should close. +screen_height+ sets the page size.
    def handle_key(key, screen_height)
      if @input then input_key(key)
      elsif @confirm then confirm_key(key)
      else
        @message = nil
        return :close if TerminalUI::QUIT_KEYS.include?(key)

        list_key(key, rows(screen_height))
      end
      nil
    rescue ActiveRecord::ActiveRecordError => e
      @message = ["Database error: #{e.message}", :error]
      nil
    end

    # The box starts at row 1, column 1: just inside the screen's frame.
    def draw(screen)
      width = screen.width - 6
      rows = rows(screen.height)
      scroll_into_view(rows)

      screen.draw_box(1, 1, screen.width - 2, screen.height - 2, " Songs · #{@show.long_title} ")
      draw_header(screen, 2, 3, width)
      @songs[@offset, rows].each_with_index do |song, index|
        draw_song(screen, 3 + index, 3, width, song, @offset + index)
      end
      draw_status(screen, screen.height - 4, 3, width)
      screen.draw_help(screen.height - 3, @confirm ? CONFIRM_HELP : HELP, col: 3, right: 3 + width)
      @input&.draw(screen)
    end

    private

    # The box is two rows smaller than the screen, and inside it are the column
    # titles, the status line and the help line.
    def rows(screen_height)
      [screen_height - 7, 1].max
    end

    def scroll_into_view(rows)
      @offset = @offset.clamp(@cursor - rows + 1, @cursor).clamp(0, [@songs.size - rows, 0].max)
    end

    def load_songs
      @songs = @show.songs.reload.to_a
      @missing = @songs.reject { |song| File.file?(path_of(song)) }.to_set(&:id)
      @playing = @playing_entry&.reload&.current_song
      @cursor = @cursor.clamp(0, [@songs.size - 1, 0].max)
    end

    # Not Song#full_file_path, which loads the show again for every song.
    def path_of(song)
      File.join(@show.folder_path, song.file_path)
    end

    def selected_song
      @songs[@cursor]
    end

    def list_key(key, page)
      case key
      when *EDIT_FILE_KEYS then edit(:file_path, 'File')
      when 't', 'T' then edit(:title, 'Title')
      when *REMOVE_KEYS then @confirm = selected_song
      else move(key, page)
      end
    end

    def move(key, page)
      target = case key
               when Curses::KEY_UP, 'k' then @cursor - 1
               when Curses::KEY_DOWN, 'j' then @cursor + 1
               when *TerminalUI::PAGE_UP_KEYS then @cursor - page
               when *TerminalUI::PAGE_DOWN_KEYS then @cursor + page
               when Curses::KEY_HOME, 'g' then 0
               when Curses::KEY_END, 'G' then @songs.size - 1
               else return
               end
      @cursor = target.clamp(0, [@songs.size - 1, 0].max)
    end

    def edit(attribute, label)
      song = selected_song
      return unless song

      @input = TextInput.new(" #{label} of song #{@cursor + 1} ", song[attribute])
      @input_attribute = attribute
    end

    def input_key(key)
      input = @input
      result = input.handle_key(key)
      return unless result

      @input = nil
      save(selected_song, @input_attribute, input.text) if result == :save
    end

    def save(song, attribute, value)
      saved = attribute == :file_path ? song.change_file_path(value) : song.update(title: value)
      @message = saved ? saved_message(song, attribute) : error_message(song)
      load_songs
    end

    def saved_message(song, attribute)
      number = @cursor + 1
      return ["Saved the title of song #{number}.", :playing] if attribute == :title
      return ["Saved, but there is no such file: #{song.file_path}", :highlight] unless File.file?(path_of(song))

      ["Saved the file of song #{number}; its length is #{format_length(song.length)}.", :playing]
    end

    def error_message(record)
      [record.errors.full_messages.join(' '), :error]
    end

    def confirm_key(key)
      song = @confirm
      @confirm = nil
      return @message = ['Remove cancelled.', :label] unless %w[y Y].include?(key)

      @message = song.destroy ? ["Removed from the show: #{song.title}", :playing] : error_message(song)
      load_songs
    end

    # [title width, file width] for a row of +width+ after the +prefix_width+
    # of the mark and number.
    def column_widths(width, prefix_width)
      rest = width - prefix_width - LENGTH_WIDTH - 4
      title_width = rest * 2 / 5
      [title_width, rest - title_width]
    end

    def number_width
      @songs.size.to_s.length
    end

    def draw_header(screen, row, col, width)
      prefix = ' ' * (number_width + 4)
      title_width, = column_widths(width, prefix.length)
      screen.put(row, col, "#{prefix}#{'Title'.ljust(title_width)}  #{'Length'.rjust(LENGTH_WIDTH)}  File", :label)
      return if @missing.empty?

      missing = "#{@missing.size} #{@missing.size == 1 ? 'file' : 'files'} not found"
      screen.put(row, col + width - missing.length, missing, :error)
    end

    def draw_song(screen, row, col, width, song, index)
      parts = song_parts(screen, width, song, index)
      return screen.put(row, col, parts.map(&:first).join.ljust(width), :cursor_selected) if index == @cursor

      parts.each do |text, style|
        screen.put(row, col, text, style)
        col += text.length
      end
    end

    # The [text, style] parts of a song's row.
    def song_parts(screen, width, song, index)
      mark, mark_style = song_mark(song, index)
      number = " #{(index + 1).to_s.rjust(number_width)}  "
      title_width, file_width = column_widths(width, mark.length + number.length)
      [[mark, mark_style], [number, :number], [screen.truncate(song.title, title_width).ljust(title_width), nil],
       ["  #{format_length(song.length).rjust(LENGTH_WIDTH)}  ", :label],
       [screen.truncate_left(song.file_path, file_width), (:error if @missing.include?(song.id))]]
    end

    def song_mark(song, index)
      if @missing.include?(song.id) then [MISSING_MARK, :error]
      elsif index == @playing then [PLAYING_MARK, :playing]
      else [' ', nil]
      end
    end

    # The status line: a question or message, or else the selected song's full path.
    def draw_status(screen, row, col, width)
      if @confirm
        question = "Remove song #{@cursor + 1} \"#{@confirm.title}\" from the show? The file is kept. [y/N]"
        screen.put(row, col, screen.truncate(question, width), :error)
      elsif @message
        screen.put(row, col, screen.truncate(@message[0], width), @message[1])
      elsif selected_song
        draw_path(screen, row, col, width, selected_song)
      end
    end

    def draw_path(screen, row, col, width, song)
      note = @missing.include?(song.id) ? '  (not found)' : ''
      path = screen.truncate_left(path_of(song), width - note.length)
      screen.put(row, col, path, :label)
      screen.put(row, col + path.length, note, :error)
    end

    # "4:05", or "1:02:03" from an hour on.
    def format_length(milliseconds)
      minutes, seconds = (milliseconds.to_i / 1000.0).round.divmod(60)
      hours, minutes = minutes.divmod(60)
      clock = "#{minutes.to_s.rjust(hours.positive? ? 2 : 1, '0')}:#{seconds.to_s.rjust(2, '0')}"
      hours.positive? ? "#{hours}:#{clock}" : clock
    end
  end
end
