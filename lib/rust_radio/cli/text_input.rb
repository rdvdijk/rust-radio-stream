# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'

module RustRadio
  # A pop-up with a one-line text field, for example for a show's notes. The
  # host UI sends it every key while it's open, so q and other shortcuts can
  # be typed, and calls #draw at the end of its own drawing.
  class TextInput
    MAX_LENGTH = 500
    HEIGHT = 7
    HELP = [%w[Enter save], %w[Esc cancel]].freeze
    BACKSPACE_KEYS = [Curses::KEY_BACKSPACE, "\x7F", "\b"].freeze
    HOME_KEYS = [Curses::KEY_HOME, "\x01"].freeze # Ctrl-A, as in a shell
    END_KEYS = [Curses::KEY_END, "\x05"].freeze # Ctrl-E

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
      field_width = width - 6

      screen.draw_box(top, left, width, HEIGHT, @title)
      draw_field(screen, top + 2, left + 3, field_width)
      screen.draw_help(top + 4, HELP, col: left + 3, right: left + width - 3)
    end

    private

    def move_or_insert(key)
      case key
      when Curses::KEY_LEFT then @cursor = [@cursor - 1, 0].max
      when Curses::KEY_RIGHT then @cursor = [@cursor + 1, @chars.size].min
      when *HOME_KEYS then @cursor = 0
      when *END_KEYS then @cursor = @chars.size
      else insert(key)
      end
    end

    def insert(key)
      return unless key.is_a?(String) && key.match?(/\A[^[:cntrl:]]\z/) && @chars.size < MAX_LENGTH

      @chars.insert(@cursor, key)
      @cursor += 1
    end

    def delete_at(index)
      return unless index.between?(0, @chars.size - 1)

      @chars.delete_at(index)
      @cursor = index
    end

    # The part of the text around the cursor that fits, with the cursor shown
    # as a highlighted character.
    def draw_field(screen, row, col, width)
      first = [@cursor - width + 1, 0].max
      screen.put(row, col, @chars[first, width].join.ljust(width), :value)
      screen.put(row, col + @cursor - first, @chars[@cursor] || ' ', :cursor_selected)
    end
  end
end
