# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'

module RustRadio
  # Full-screen terminal UI that lists the FLAC files of a show folder and
  # asks the user to confirm adding it. #run returns :add or :cancel.
  class AddShowUI < TerminalUI
    TITLE = ' Rust Radio · Add show '
    HELP = [['↑/↓', 'scroll'], ['←/→/Tab', 'select'], ['Enter', 'confirm'], ['q/Esc', 'cancel']].freeze
    BUTTON_LABELS = { add: 'Add show', cancel: 'Cancel', ok: 'OK' }.freeze

    HEADER_ROWS = 4 # top border, folder, playlist, list separator
    FOOTER_ROWS = 5 # separator, buttons, separator, help, bottom border
    MIN_HEIGHT = HEADER_ROWS + FOOTER_ROWS + 1

    def initialize(folder_path, playlist_name, flac_files)
      super()
      @folder_path = folder_path
      @playlist_name = playlist_name
      @flac_files = flac_files
      @buttons = BUTTON_LABELS.slice(*(flac_files.empty? ? [:ok] : %i[add cancel]))
      @selected = 0
      @offset = 0
    end

    private

    # --- Input ---------------------------------------------------------------

    def handle_key(key)
      case key
      when *ENTER_KEYS then @buttons.keys[@selected] == :add ? :add : :cancel
      when *QUIT_KEYS then :cancel
      else
        navigate(key)
        nil
      end
    end

    def navigate(key)
      case key
      when Curses::KEY_UP then scroll_by(-1)
      when Curses::KEY_DOWN then scroll_by(1)
      when Curses::KEY_PPAGE then scroll_by(-list_rows)
      when Curses::KEY_NPAGE, ' ' then scroll_by(list_rows)
      when Curses::KEY_HOME then @offset = 0
      when Curses::KEY_END then @offset = max_offset
      when Curses::KEY_LEFT, Curses::KEY_BTAB then select_button(-1)
      when Curses::KEY_RIGHT, *TAB_KEYS then select_button(1)
      end
    end

    def scroll_by(rows)
      @offset = (@offset + rows).clamp(0, max_offset)
    end

    def select_button(step)
      @selected = (@selected + step) % @buttons.size
    end

    def list_rows
      [@height - HEADER_ROWS - FOOTER_ROWS, 1].max
    end

    def max_offset
      [@flac_files.size - list_rows, 0].max
    end

    # --- Drawing -------------------------------------------------------------

    def draw_screen
      @offset = @offset.clamp(0, max_offset)
      draw_frame(TITLE, [@height - 5, @height - 3])
      horizontal_line(HEADER_ROWS - 1, '├', '┤', " FLAC files (#{@flac_files.size}) ")
      draw_header
      @flac_files.empty? ? draw_empty : draw_files
      draw_buttons(@height - 4, @buttons, @selected)
      draw_help(@height - 2, HELP)
    end

    def draw_header
      value_width = @width - 14
      put(1, 2, 'Folder:', :label)
      put(1, 12, truncate_left(@folder_path, value_width), :value)
      put(2, 2, 'Playlist:', :label)
      put(2, 12, truncate(@playlist_name, value_width), :highlight)
    end

    def draw_files
      number_width = @flac_files.size.to_s.length + 3
      name_col = 1 + number_width + 2
      name_width = @width - name_col - 2 - (max_offset.positive? ? SCROLL_HINT_WIDTH : 0)

      @flac_files[@offset, list_rows].each_with_index do |file, index|
        row = HEADER_ROWS + index
        put(row, 1, (@offset + index + 1).to_s.rjust(number_width), :number)
        put(row, name_col, truncate(file, name_width))
      end
      below = @flac_files.size - @offset - list_rows
      draw_scroll_hints(HEADER_ROWS, list_rows, @width - 2, @offset, below)
    end

    def draw_empty
      put(HEADER_ROWS + 1, 4, 'No FLAC files found in this folder.', :highlight)
    end
  end
end
