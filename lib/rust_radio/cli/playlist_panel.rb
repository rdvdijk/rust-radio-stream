# frozen_string_literal: true

module RustRadio
  # One of the two lists of the playlist UI: the playlist entries on the left,
  # the shows not on the playlist on the right. The UI owns the items and the
  # cursor; the panel keeps the scroll offset, which follows the cursor.
  class PlaylistPanel
    # +playing+: whether the first entry is playing. +search+: a
    # PlaylistSearch whose matches are highlighted, or nil.
    View = Data.define(:items, :cursor, :active, :playing, :search)

    # +title+ gives the text shown for an item; +missing+ tells whether an
    # item's show folder is gone.
    def initialize(side, screen, title, missing)
      @side = side
      @screen = screen
      @title = title
      @missing = missing
      @offset = 0
    end

    # The count in the panel's title: "42", or "42, 1 missing".
    def count_label(items)
      missing = items.count(&@missing)
      missing.positive? ? "#{items.size}, #{missing} missing" : items.size.to_s
    end

    def draw(top, col, width, view)
      @view = view
      return draw_empty(top, col) if view.items.empty?

      scroll_into_view
      rows = @screen.list_rows
      above = @offset
      below = view.items.size - above - rows
      view.items[above, rows].each_with_index do |item, index|
        draw_item(item, above + index, top + index, col, width, hint: @screen.scroll_hint_row?(index, above, below))
      end
      @screen.draw_scroll_hints(top, col + width - 1, above, below)
    end

    private

    def scroll_into_view
      cursor = @view.cursor
      rows = @screen.list_rows
      @offset = cursor if cursor < @offset
      @offset = cursor - rows + 1 if cursor >= @offset + rows
      @offset = @offset.clamp(0, [@view.items.size - rows, 0].max)
    end

    # +hint+: the row shares space with a "▲/▼ N more" hint.
    def draw_item(item, index, row, col, width, hint: false)
      prefix, prefix_style = item_prefix(item, index)
      text_width = width - prefix.length - 1 - (hint ? TerminalUI::SCROLL_HINT_WIDTH : 0)
      text = @screen.truncate(@title.call(item), text_width)

      if index == @view.cursor && @view.active
        @screen.put(row, col, "#{prefix}#{text}".ljust(width), :cursor_selected)
      else
        @screen.put(row, col, prefix, prefix_style)
        text_style = if @view.search&.match?(item) then :mark
                     elsif @missing.call(item) then :error
                     elsif index == @view.cursor then :cursor
                     end
        @screen.put(row, col + prefix.length, text, text_style)
      end
    end

    # The " ▶ 1  " in front of a playlist entry, or just a margin for other
    # shows. The margin holds a mark when the show's folder is gone.
    def item_prefix(item, index)
      missing = @missing.call(item)
      margin = missing ? SongList::MISSING_MARK : ' '
      return [margin, (:error if missing)] if @side == :right

      playing = index.zero? && @view.playing
      number = item.position.to_s.rjust(@view.items.size.to_s.length)
      style = if missing then :error
              elsif playing then :playing
              else :number
              end
      ["#{margin}#{playing ? '▶' : ' '} #{number}  ", style]
    end

    def draw_empty(top, col)
      text = @side == :left ? 'The playlist is empty.' : 'All shows are on the playlist.'
      @screen.put(top, col + 2, text, :label)
    end
  end
end
