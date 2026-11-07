# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'

module RustRadio
  # A pop-up with a word-wrapped text field, for example for a show's notes. The
  # host UI sends it every key while it's open, so q and other shortcuts can
  # be typed, and calls #draw at the end of its own drawing.
  class TextInput
    MAX_LENGTH = 500
    FIELD_ROWS = 4
    HEIGHT = FIELD_ROWS + 6
    HELP = [%w[Enter save], %w[Esc cancel]].freeze
    BACKSPACE_KEYS = [Curses::KEY_BACKSPACE, "\x7F", "\b"].freeze
    HOME_KEYS = [Curses::KEY_HOME, "\x01"].freeze # Ctrl-A, as in a shell
    END_KEYS = [Curses::KEY_END, "\x05"].freeze # Ctrl-E

    # Whether +key+ is a typed character rather than a control or function key.
    def self.printable?(key)
      key.is_a?(String) && key.match?(/\A[^[:cntrl:]]\z/)
    end

    def initialize(title, text = nil)
      @title = title
      @chars = text.to_s.chars
      @cursor = @chars.size
    end

    def text
      @chars.join.strip
    end

    # Returns :save or :cancel when the input is done.
    def handle_key(key)
      case key
      when *TerminalUI::ENTER_KEYS then return :save
      when *TerminalUI::ESCAPE_KEYS then return :cancel
      when *BACKSPACE_KEYS then delete_at(@cursor - 1)
      when Curses::KEY_DC then delete_at(@cursor)
      else move_or_insert(key)
      end
      nil
    end

    def draw(screen)
      width = [screen.width - 4, TerminalUI::POPUP_MAX_WIDTH].min
      top = (screen.height - HEIGHT) / 2
      left = (screen.width - width) / 2
      @field_width = width - 6

      screen.draw_box(top, left, width, HEIGHT, @title)
      draw_field(screen, top + 2, left + 3)
      screen.draw_help(top + 3 + FIELD_ROWS, HELP, col: left + 3, right: left + width - 3)
    end

    private

    def move_or_insert(key)
      case key
      when Curses::KEY_LEFT then @cursor = [@cursor - 1, 0].max
      when Curses::KEY_RIGHT then @cursor = [@cursor + 1, @chars.size].min
      when Curses::KEY_UP then move_line(-1)
      when Curses::KEY_DOWN then move_line(1)
      when *HOME_KEYS then @cursor = 0
      when *END_KEYS then @cursor = @chars.size
      else insert(key)
      end
    end

    def insert(key)
      return unless TextInput.printable?(key) && @chars.size < MAX_LENGTH

      @chars.insert(@cursor, key)
      @cursor += 1
    end

    def delete_at(index)
      return unless index.between?(0, @chars.size - 1)

      @chars.delete_at(index)
      @cursor = index
    end

    # Moves the cursor to the same column on the line +offset+ lines away,
    # or to the end of that line if it's shorter.
    def move_line(offset)
      return unless @field_width

      lines = wrapped_lines
      index = cursor_line(lines)
      target = index + offset
      return unless target.between?(0, lines.size - 1)

      start, length = lines[target]
      # Position start + length is already the start of the next line, except
      # on the last line, where it's the end of the text.
      max_column = target == lines.size - 1 ? length : length - 1
      @cursor = start + [@cursor - lines[index][0], max_column].min
    end

    # The text as [start, length] lines of at most @field_width characters,
    # broken after the last space that fits. A line keeps its trailing space,
    # so every character, and so every cursor position, is on a line.
    def wrapped_lines
      lines = []
      start = 0
      while @chars.size - start > @field_width
        space = @chars[start, @field_width].rindex(' ')
        length = space ? space + 1 : @field_width
        lines << [start, length]
        start += length
      end
      lines << [start, @chars.size - start]
      # A cursor at the end of a full last line goes on a new, empty line.
      lines << [@chars.size, 0] if lines.last[1] == @field_width
      lines
    end

    def cursor_line(lines)
      lines.rindex { |start, _length| start <= @cursor }
    end

    # The FIELD_ROWS lines around the cursor, with the cursor shown as a
    # highlighted character.
    def draw_field(screen, row, col)
      lines = wrapped_lines
      index = cursor_line(lines)
      @first_line = (@first_line || 0).clamp(index - FIELD_ROWS + 1, index)
      first = @first_line.clamp(0, [lines.size - FIELD_ROWS, 0].max)
      FIELD_ROWS.times do |offset|
        start, length = lines[first + offset] || [0, 0]
        screen.put(row + offset, col, @chars[start, length].join.ljust(@field_width), :value)
      end
      cursor_col = @cursor - lines[index][0]
      screen.put(row + index - first, col + cursor_col, @chars[@cursor] || ' ', :cursor_selected)
    end
  end
end
