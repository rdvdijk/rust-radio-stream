# frozen_string_literal: true

require 'curses'

module RustRadio
  # Base class for the full-screen terminal UIs: curses setup and teardown,
  # the shared color scheme, the main loop and drawing helpers.
  #
  # Subclasses implement #draw_screen (called when the terminal is big enough)
  # and #handle_key, which returns a non-nil value to end #run with. They
  # define HEADER_ROWS and FOOTER_ROWS, the rows around their list.
  #
  # Only real keys reach #handle_key: a getch timeout or a terminal resize
  # goes to #on_idle instead, followed by a redraw.
  class TerminalUI
    # getch returns control characters as Integers; accept Strings too, to be safe.
    ENTER_KEYS = [10, 13, "\n", "\r", Curses::KEY_ENTER].freeze
    TAB_KEYS = [9, "\t"].freeze
    ESCAPE_KEYS = [27, "\e"].freeze
    QUIT_KEYS = [*ESCAPE_KEYS, 'q', 'Q'].freeze
    # Scrolling by a page, as in less: Shift+Space can't be told apart from Space.
    PAGE_DOWN_KEYS = [Curses::KEY_NPAGE, ' ', 'f'].freeze
    PAGE_UP_KEYS = [Curses::KEY_PPAGE, 'b'].freeze

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
      error: [Curses::COLOR_RED, -1],
      mark: [Curses::COLOR_BLACK, Curses::COLOR_YELLOW], # something to look at, like an odd character
      ok_selected: [Curses::COLOR_BLACK, Curses::COLOR_WHITE]
    }.freeze

    ATTRIBUTES = {
      border: Curses::A_DIM, label: Curses::A_DIM, number: Curses::A_DIM, help: Curses::A_DIM,
      title: Curses::A_BOLD, value: Curses::A_BOLD, key: Curses::A_BOLD, cursor: Curses::A_BOLD,
      add_selected: Curses::A_BOLD, cancel_selected: Curses::A_BOLD, ok_selected: Curses::A_BOLD,
      playing: Curses::A_BOLD, error: Curses::A_BOLD, mark: Curses::A_BOLD
    }.freeze

    POPUP_MAX_WIDTH = 76

    # The screen size, as of the last draw. Public, like the drawing helpers
    # at the bottom, for overlays such as TextViewer that draw onto this UI.
    attr_reader :width, :height

    # Runs the UI until #handle_key returns a value, and returns that value.
    # Ctrl-C returns +interrupt_result+.
    def run(interrupt_result: :cancel)
      setup
      loop do
        draw
        key = Curses.getch
        if key.nil? || key == Curses::KEY_RESIZE
          on_idle(key)
          next
        end

        result = handle_key(key)
        return result if result
      end
    rescue Interrupt
      interrupt_result
    ensure
      Curses.close_screen if @screen_open
    end

    private

    # Called on a getch timeout (+key+ nil) or a resize, instead of #handle_key.
    def on_idle(_key); end

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

    # Curses attributes for a style name. Without color support, a style
    # drawn on a colored background falls back to reverse video.
    def style(name)
      attrs = ATTRIBUTES.fetch(name, Curses::A_NORMAL)
      pair_index = COLOR_PAIRS.keys.index(name)
      if @colors && pair_index
        attrs | Curses.color_pair(pair_index + 1)
      elsif pair_index && COLOR_PAIRS[name][1] != -1
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

    # An empty box with +title+ in its top border, drawn over what's there.
    def draw_box(top, left, width, height, title, style_name = :title)
      put(top, left, "┌#{'─' * (width - 2)}┐", style_name)
      put(top, left + 2, truncate(title, width - 4), style_name)
      (1...(height - 1)).each { |offset| put(top + offset, left, "│#{' ' * (width - 2)}│", style_name) }
      put(top + height - 1, left, "└#{'─' * (width - 2)}┘", style_name)
    end

    # A box centered on the screen: optional +message+ lines, label/value
    # +rows+, and an optional +hint+ at the bottom right. A row is
    # [label, value, value_style = :value, cut = :end]; cut :start shortens a
    # long value from the left, which keeps the end of a path visible.
    def draw_popup(title, rows, message: [], style: :title, hint: nil)
      label_width = (rows.map { |label, _value| label.length }.max || 0) + 2
      content = [*message.map(&:length), *rows.map { |_label, value| label_width + value.length }, title.length + 2].max
      width = [content + 6, POPUP_MAX_WIDTH, @width - 4].min
      lines = (message.any? ? message.size + 1 : 0) + rows.size + (hint ? 2 : 0)
      height = [lines + 4, @height - 2].min # borders, and a blank line at the top and bottom
      top = [(@height - height) / 2, 0].max
      left = (@width - width) / 2

      draw_box(top, left, width, height, title, style)
      message.each_with_index { |line, index| put(top + 2 + index, left + 3, truncate(line, width - 6), :value) }
      first_row = top + 2 + (message.any? ? message.size + 1 : 0)
      draw_popup_rows(rows, first_row, top + height - 3 - (hint ? 2 : 0), left + 3, width - 6, label_width)
      put(top + height - 3, left + width - 3 - hint.length, hint, :help) if hint
    end

    def draw_popup_rows(rows, first_row, last_row, col, width, label_width)
      rows.each_with_index do |(label, value, value_style, cut), index|
        row = first_row + index
        break if row > last_row

        value_width = width - label_width
        value = cut == :start ? truncate_left(value, value_width) : truncate(value, value_width)
        put(row, col, label, :label)
        put(row, col + label_width, value, value_style || :value)
      end
    end

    # Rows available for the list between the header and the footer.
    def list_rows
      [@height - self.class::HEADER_ROWS - self.class::FOOTER_ROWS, 1].max
    end

    # The index of the last item, or 0 for an empty list; for clamping.
    def last_index(count)
      [count - 1, 0].max
    end

    # "▲ N more" on the first list row and "▼ N more" on the last one.
    def draw_scroll_hints(first_row, right_col, above, below)
      { first_row => ("▲ #{above} more" if above.positive?),
        first_row + list_rows - 1 => ("▼ #{below} more" if below.positive?) }.each do |row, text|
        put(row, right_col - text.length, text, :highlight) if text
      end
    end

    # Whether visible row +index+ shares its row with a scroll hint, and
    # so has SCROLL_HINT_WIDTH less room for text.
    def scroll_hint_row?(index, above, below)
      (index.zero? && above.positive?) || (index == list_rows - 1 && below.positive?)
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

    # A help line of [key, action, short_key] items from +col+ up to +right+.
    # If the line doesn't fit, items use their short key (if they have one);
    # items that still don't fit are left out.
    def draw_help(row, items, col: 2, right: @width - 2)
      full_width = items.sum { |key, action| key.length + action.length + 1 } + (3 * (items.size - 1))
      items = items.map { |key, action, short_key| [short_key || key, action] } if col + full_width > right

      items.each_with_index do |(key, action), index|
        separator = index.zero? ? '' : ' · '
        hint = " #{action}"
        break if col + separator.length + key.length + hint.length > right

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

    # The drawing API for overlays (see #width and #height).
    public :put, :draw_box, :draw_help, :truncate, :truncate_left, :last_index
  end
end
