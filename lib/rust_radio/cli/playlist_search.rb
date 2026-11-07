# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'
require 'rust_radio/cli/text_input'

module RustRadio
  # The / search of the playlist UI, typed on the status line. After Enter it
  # stays around, no longer typing, to keep the matches highlighted. Searches
  # the UI's items, a { side => [item] } hash, by the title the block gives.
  class PlaylistSearch
    HELP = [%w[Enter done], ['Esc', 'clear search']].freeze

    def initialize(&title)
      @title = title
      @text = ''
      @typing = true
      @first_matches = {}
      @matches = Set.new
    end

    def typing?
      @typing
    end

    # Returns :done or :cancel when typing ends, :changed when the text changed.
    def handle_key(key)
      case key
      when *TerminalUI::ENTER_KEYS then @text.empty? ? :cancel : done
      when *TerminalUI::ESCAPE_KEYS then :cancel
      when *TextInput::BACKSPACE_KEYS then backspace
      else insert(key)
      end
    end

    # Finds the matches in +items+; call it when the text or the items change.
    # Matching every title once here keeps drawing, which happens on every
    # key and refresh, to set lookups.
    def find(items)
      query = @text.downcase
      @matches = Set.new
      @first_matches = {}
      return if query.empty?

      items.each do |side, list|
        list.each_with_index do |item, index|
          next unless @title.call(item).downcase.include?(query)

          @matches << item
          @first_matches[side] ||= index
        end
      end
    end

    def match?(item)
      @matches.include?(item)
    end

    # [side, index] of the first match, trying the sides in the order find got them.
    def first_match
      @first_matches.first
    end

    def draw(screen, row)
      count = @matches.size
      result = if @text.empty? then ''
               elsif count.zero? then 'no matches'
               else "#{count} #{count == 1 ? 'match' : 'matches'}"
               end
      screen.put(row, screen.width - 2 - result.length, result, count.zero? ? :error : :label) unless result.empty?
      screen.put(row, 2, '/', :key)
      text = screen.truncate_left(@text, screen.width - 8 - result.length)
      screen.put(row, 3, text, :value)
      screen.put(row, 3 + text.length, ' ', :cursor_selected) if @typing
    end

    private

    def done
      @typing = false
      :done
    end

    def backspace
      return :cancel if @text.empty?

      @text = @text.chop
      :changed
    end

    def insert(key)
      return unless TextInput.printable?(key)

      @text += key
      :changed
    end
  end
end
