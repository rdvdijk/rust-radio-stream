# frozen_string_literal: true

require 'curses'

module RustRadio
  # Base class for the full-screen terminal UIs: curses setup and teardown,
  # the shared color scheme, the main loop and drawing helpers.
  #
  # Subclasses implement #draw_screen (called when the terminal is big enough)
  # and #handle_key, which returns a non-nil value to end #run with.
  class TerminalUI
    # getch returns control characters as Integers; accept Strings too, to be safe.
    ENTER_KEYS = [10, 13, "\n", "\r", Curses::KEY_ENTER].freeze
    TAB_KEYS = [9, "\t"].freeze
    ESCAPE_KEYS = [27, "\e"].freeze
    QUIT_KEYS = [*ESCAPE_KEYS, 'q', 'Q'].freeze

    MIN_WIDTH = 40
    MIN_HEIGHT = 10
    SCROLL_HINT_WIDTH = 12
    BUTTON_GAP = 7

    # Style name => [foreground, background]; -1 is the terminal's default color.
    COLOR_PAIRS = {
      title: [Curses::COLOR_CYAN, -1],
      highlight: [Curses::COLOR_YELLOW, -1],
      add: [Curses::COLOR_GREEN, -1],
      add_selected: [Curses::COLOR_BLACK, Curses::COLOR_GREEN],
      cancel: [Curses::COLOR_RED, -1],
      cancel_selected: [Curses::COLOR_BLACK, Curses::COLOR_RED],
      cursor_selected: [Curses::COLOR_BLACK, Curses::COLOR_CYAN],
      playing: [Curses::COLOR_GREEN, -1],
      error: [Curses::COLOR_RED, -1]
    }.freeze

    ATTRIBUTES = {
      border: Curses::A_DIM, label: Curses::A_DIM, number: Curses::A_DIM, help: Curses::A_DIM,
      title: Curses::A_BOLD, value: Curses::A_BOLD, key: Curses::A_BOLD, cursor: Curses::A_BOLD,
      add_selected: Curses::A_BOLD, cancel_selected: Curses::A_BOLD, ok_selected: Curses::A_BOLD,
      playing: Curses::A_BOLD, error: Curses::A_BOLD
    }.freeze

    # Runs the UI until #handle_key returns a value, and returns that value.
    # Ctrl-C returns +interrupt_result+.
    def run(interrupt_result: :cancel)
      setup
      loop do
        draw
        result = handle_key(Curses.getch)
        return result if result
      end
    rescue Interrupt
      interrupt_result
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

    # Curses attributes for a style name. Without color support, "*_selected"
    # styles fall back to reverse video.
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

    # --- Drawing -------------------------------------------------------------

    def draw
      @height = Curses.lines
      @width = Curses.cols
      Curses.stdscr.erase
      if @height < self.class::MIN_HEIGHT || @width < self.class::MIN_WIDTH
        draw_too_small
      else
        draw_screen
      end
      Curses.refresh
    end

    def draw_too_small
      put(0, 0, 'Terminal too small,', :highlight)
      put(1, 0, "need #{self.class::MIN_WIDTH}x#{self.class::MIN_HEIGHT}.", :highlight)
      put(2, 0, 'Press q to quit.')
    end

    # The outer box, with a horizontal separator on each row in +separators+.
    def draw_frame(title, separators)
      (1...(@height - 1)).each do |row|
        put(row, 0, '│', :border)
        put(row, @width - 1, '│', :border)
      end
      horizontal_line(0, '┌', '┐', title)
      separators.each { |row| horizontal_line(row, '├', '┤') }
      horizontal_line(@height - 1, '└', '┘')
    end

    def horizontal_line(row, left, right, title = nil)
      put(row, 0, "#{left}#{'─' * (@width - 2)}#{right}", :border)
      put(row, 2, title, :title) if title
    end

    def draw_scroll_hints(first_row, rows, right_col, above, below)
      draw_scroll_hint(first_row, right_col, "▲ #{above} more") if above.positive?
      draw_scroll_hint(first_row + rows - 1, right_col, "▼ #{below} more") if below.positive?
    end

    def draw_scroll_hint(row, right_col, text)
      put(row, right_col - text.length, text, :highlight)
    end

    # Buttons centered on +row+; +buttons+ maps button names to labels.
    def draw_buttons(row, buttons, selected)
      labels = buttons.each_with_index.map do |(_name, label), index|
        index == selected ? "[ #{label} ]" : "< #{label} >"
      end
      col = [(@width - labels.sum(&:length) - (BUTTON_GAP * (labels.size - 1))) / 2, 1].max

      buttons.keys.each_with_index do |name, index|
        put(row, col, labels[index], index == selected ? :"#{name}_selected" : name)
        col += labels[index].length + BUTTON_GAP
      end
    end

    # A help line of [key, action] pairs. Pairs that don't fit are left out.
    def draw_help(row, items)
      col = 2
      items.each_with_index do |(key, action), index|
        separator = index.zero? ? '' : ' · '
        hint = " #{action}"
        break if col + separator.length + key.length + hint.length > @width - 2

        put(row, col, separator, :help)
        col += separator.length
        put(row, col, key, :key)
        put(row, col + key.length, hint, :help)
        col += key.length + hint.length
      end
    end

    # --- Helpers -------------------------------------------------------------

    def put(row, col, text, style_name = nil)
      return if col >= @width || row >= @height || col.negative?

      attrs = style_name ? style(style_name) : Curses::A_NORMAL
      window = Curses.stdscr
      window.setpos(row, col)
      window.attron(attrs)
      window.addstr(text[0, @width - col])
      window.attroff(attrs)
    end

    def truncate(text, width)
      return text if text.length <= width
      return '' unless width.positive?

      "#{text[0, width - 1]}…"
    end

    def truncate_left(text, width)
      return text if text.length <= width
      return '' unless width.positive?

      "…#{text[(text.length - width + 1)..]}"
    end
  end
end
