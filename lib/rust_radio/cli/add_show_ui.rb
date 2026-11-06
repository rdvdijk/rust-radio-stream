# frozen_string_literal: true

require 'curses'

module RustRadio
  # Full-screen terminal UI that lists the FLAC files of a show folder and
  # asks the user to confirm adding it. #run returns :add or :cancel.
  class AddShowUI
    TITLE = ' Rust Radio · Add show '
    HELP = [['↑/↓', 'scroll'], ['←/→/Tab', 'select'], ['Enter', 'confirm'], ['q/Esc', 'cancel']].freeze
    BUTTON_LABELS = { add: 'Add show', cancel: 'Cancel', ok: 'OK' }.freeze
    BUTTON_GAP = 7

    # getch returns control characters as Integers; accept Strings too, to be safe.
    ENTER_KEYS = [10, 13, "\n", "\r", Curses::KEY_ENTER].freeze
    TAB_KEYS = [9, "\t"].freeze
    CANCEL_KEYS = [27, "\e", 'q', 'Q'].freeze

    HEADER_ROWS = 4 # top border, folder, playlist, list separator
    FOOTER_ROWS = 5 # separator, buttons, separator, help, bottom border
    MIN_HEIGHT = HEADER_ROWS + FOOTER_ROWS + 1
    MIN_WIDTH = 40
    SCROLL_HINT_WIDTH = 12

    # Style name => [foreground, background]; -1 is the terminal's default color.
    COLOR_PAIRS = {
      title: [Curses::COLOR_CYAN, -1],
      highlight: [Curses::COLOR_YELLOW, -1],
      add: [Curses::COLOR_GREEN, -1],
      add_selected: [Curses::COLOR_BLACK, Curses::COLOR_GREEN],
      cancel: [Curses::COLOR_RED, -1],
      cancel_selected: [Curses::COLOR_BLACK, Curses::COLOR_RED]
    }.freeze

    ATTRIBUTES = {
      border: Curses::A_DIM, label: Curses::A_DIM, number: Curses::A_DIM, help: Curses::A_DIM,
      title: Curses::A_BOLD, value: Curses::A_BOLD, key: Curses::A_BOLD,
      add_selected: Curses::A_BOLD, cancel_selected: Curses::A_BOLD, ok_selected: Curses::A_BOLD
    }.freeze

    def initialize(folder_path, playlist_name, flac_files)
      @folder_path = folder_path
      @playlist_name = playlist_name
      @flac_files = flac_files
      @buttons = flac_files.empty? ? [:ok] : %i[add cancel]
      @selected = 0
      @offset = 0
    end

    def run
      setup
      loop do
        draw
        result = handle_key(Curses.getch)
        return result if result
      end
    rescue Interrupt
      :cancel
    ensure
      Curses.close_screen if @screen_open
    end

    private

    # --- Setup ---------------------------------------------------------------

    def setup
      ENV['ESCDELAY'] ||= '25' # don't wait a full second after Esc
      Curses.init_screen
      @screen_open = true
      Curses.noecho
      Curses.cbreak
      Curses.curs_set(0)
      Curses.stdscr.keypad(true)
      setup_colors
    end

    def setup_colors
      @colors = Curses.has_colors?
      return unless @colors

      Curses.start_color
      Curses.use_default_colors
      COLOR_PAIRS.each_with_index do |(_name, (fg, bg)), index|
        Curses.init_pair(index + 1, fg, bg)
      end
    end

    def style(name)
      attrs = ATTRIBUTES.fetch(name, Curses::A_NORMAL)
      pair_index = COLOR_PAIRS.keys.index(name)
      if @colors && pair_index
        attrs | Curses.color_pair(pair_index + 1)
      elsif name.to_s.end_with?('_selected')
        attrs | Curses::A_REVERSE
      else
        attrs
      end
    end

    # --- Input ---------------------------------------------------------------

    def handle_key(key)
      case key
      when *ENTER_KEYS then @buttons[@selected] == :add ? :add : :cancel
      when *CANCEL_KEYS then :cancel
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

    def draw
      @height = Curses.lines
      @width = Curses.cols
      Curses.stdscr.erase
      if @height < MIN_HEIGHT || @width < MIN_WIDTH
        put(0, 0, 'Terminal too small,', :highlight)
        put(1, 0, "need #{MIN_WIDTH}x#{MIN_HEIGHT}.", :highlight)
        put(2, 0, 'Press q to cancel.')
      else
        @offset = @offset.clamp(0, max_offset)
        draw_frame
        draw_header
        @flac_files.empty? ? draw_empty : draw_files
        draw_buttons
        draw_help
      end
      Curses.refresh
    end

    def draw_frame
      (1...(@height - 1)).each do |row|
        put(row, 0, '│', :border)
        put(row, @width - 1, '│', :border)
      end
      horizontal_line(0, '┌', '┐', TITLE)
      horizontal_line(HEADER_ROWS - 1, '├', '┤', " FLAC files (#{@flac_files.size}) ")
      horizontal_line(@height - 5, '├', '┤')
      horizontal_line(@height - 3, '├', '┤')
      horizontal_line(@height - 1, '└', '┘')
    end

    def horizontal_line(row, left, right, title = nil)
      put(row, 0, "#{left}#{'─' * (@width - 2)}#{right}", :border)
      put(row, 2, title, :title) if title
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
      draw_scroll_hints
    end

    def draw_scroll_hints
      below = @flac_files.size - @offset - list_rows
      draw_scroll_hint(HEADER_ROWS, "▲ #{@offset} more") if @offset.positive?
      draw_scroll_hint(HEADER_ROWS + list_rows - 1, "▼ #{below} more") if below.positive?
    end

    def draw_scroll_hint(row, text)
      put(row, @width - 2 - text.length, text, :highlight)
    end

    def draw_empty
      put(HEADER_ROWS + 1, 4, 'No FLAC files found in this folder.', :highlight)
    end

    def draw_buttons
      labels = @buttons.each_with_index.map do |button, index|
        index == @selected ? "[ #{BUTTON_LABELS[button]} ]" : "< #{BUTTON_LABELS[button]} >"
      end
      total = labels.sum(&:length) + (BUTTON_GAP * (labels.size - 1))
      col = [(@width - total) / 2, 1].max

      @buttons.each_with_index do |button, index|
        put(@height - 4, col, labels[index], index == @selected ? :"#{button}_selected" : button)
        col += labels[index].length + BUTTON_GAP
      end
    end

    def draw_help
      col = 2
      HELP.each_with_index do |(key, action), index|
        separator = index.zero? ? '' : ' · '
        hint = " #{action}"
        break if col + separator.length + key.length + hint.length > @width - 2 # drop hints that don't fit

        put(@height - 2, col, separator, :help)
        col += separator.length
        put(@height - 2, col, key, :key)
        put(@height - 2, col + key.length, hint, :help)
        col += key.length + hint.length
      end
    end

    # --- Helpers -------------------------------------------------------------

    def put(row, col, text, style_name = nil)
      return if col >= @width || row >= @height

      attrs = style_name ? style(style_name) : Curses::A_NORMAL
      window = Curses.stdscr
      window.setpos(row, col)
      window.attron(attrs)
      window.addstr(text[0, @width - col])
      window.attroff(attrs)
    end

    def truncate(text, width)
      return text if text.length <= width

      "#{text[0, [width - 1, 0].max]}…"
    end

    def truncate_left(text, width)
      return text if text.length <= width

      "…#{text[-[width - 1, 0].max..]}"
    end
  end
end
