# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'

module RustRadio
  # Full-screen terminal UI to manage a playlist: the shows on the playlist on
  # the left, the shows not on it on the right. Enter moves the selected show
  # to the other side; shows on the right can be deleted from the database.
  class PlaylistUI < TerminalUI
    TITLE = ' Rust Radio · Playlist '
    SIDES = %i[left right].freeze

    HEADER_ROWS = 3 # top border, playlist line, panel titles
    FOOTER_ROWS = 5 # panel bottom, status line, separator, help, bottom border
    MIN_HEIGHT = HEADER_ROWS + FOOTER_ROWS + 2
    MIN_WIDTH = 60

    REFRESH_MS = 2000 # reload periodically, the radio changes the playlist as it plays
    DELETE_KEYS = ['d', 'D', Curses::KEY_DC].freeze
    MOVE_KEYS = [*ENTER_KEYS, ' '].freeze
    SHUFFLE_KEYS = %w[s S].freeze
    # On the left these reorder the playlist; on the right they just move the cursor.
    REORDER_KEYS = %w[k j g G].freeze
    CURSOR_ALIASES = { 'k' => Curses::KEY_UP, 'j' => Curses::KEY_DOWN,
                       'g' => Curses::KEY_HOME, 'G' => Curses::KEY_END }.freeze

    def initialize(playlist)
      super()
      @playlist = playlist
      @active = :left
      @cursor = { left: 0, right: 0 }
      @offset = { left: 0, right: 0 }
      @items = { left: [], right: [] }
      @message = nil
      @confirm = nil
      reload_data
    end

    def run
      super(interrupt_result: :quit)
    end

    private

    def setup
      super
      Curses.stdscr.timeout = REFRESH_MS
    end

    # --- Data ----------------------------------------------------------------

    def reload_data
      selected_ids = SIDES.to_h { |side| [side, selected_item(side)&.id] }
      @playlist.reload
      @items = {
        left: @playlist.entries.includes(:show).to_a,
        right: Show.where.not(id: @playlist.entries.where.not(show_id: nil).select(:show_id))
                   .order(:date, :artist).to_a
      }
      SIDES.each { |side| restore_cursor(side, selected_ids[side]) }
    end

    # Keep the same item selected; if it's gone, stay at the same position.
    def restore_cursor(side, selected_id)
      index = @items[side].index { |item| item.id == selected_id }
      @cursor[side] = (index || @cursor[side]).clamp(0, [@items[side].size - 1, 0].max)
    end

    def selected_item(side = @active)
      @items[side][@cursor[side]]
    end

    def show_of(item)
      item.is_a?(PlaylistEntry) ? item.show : item
    end

    # --- Input ---------------------------------------------------------------

    def handle_key(key)
      return answer_confirm(key) if @confirm
      return :quit if QUIT_KEYS.include?(key)

      @message = nil unless key.nil? || key == Curses::KEY_RESIZE
      perform(key)
      nil
    rescue ActiveRecord::ActiveRecordError => e
      @message = ["Database error: #{e.message}", :error]
      nil
    end

    def perform(key)
      case key
      when nil, 'r', 'R' then reload_data
      when *TAB_KEYS, Curses::KEY_BTAB then @active = @active == :left ? :right : :left
      when Curses::KEY_LEFT then @active = :left
      when Curses::KEY_RIGHT then @active = :right
      when *MOVE_KEYS then move_selected
      when 'l' then move_selected if @active == :left # left → right: remove from playlist
      when 'h' then move_selected if @active == :right # right → left: add to playlist
      when *REORDER_KEYS then @active == :left ? reorder_selected(key) : move_cursor(CURSOR_ALIASES[key])
      when *SHUFFLE_KEYS then ask_shuffle
      when *DELETE_KEYS then ask_delete
      else move_cursor(key)
      end
    end

    def move_cursor(key)
      steps = { Curses::KEY_UP => -1, Curses::KEY_DOWN => 1, Curses::KEY_PPAGE => -list_rows,
                Curses::KEY_NPAGE => list_rows, Curses::KEY_HOME => -@items[@active].size,
                Curses::KEY_END => @items[@active].size }
      return unless steps.key?(key)

      @cursor[@active] = (@cursor[@active] + steps[key]).clamp(0, [@items[@active].size - 1, 0].max)
    end

    # --- Actions -------------------------------------------------------------

    def move_selected
      item = selected_item
      return unless item

      @active == :left ? remove_entry(item) : add_show(item)
      reload_data
    end

    def add_show(show)
      @playlist.entries.create!(show: show)
      @message = ["Added to the playlist: #{show.long_title}", :playing]
    end

    def remove_entry(entry)
      @message = if entry.destroy
                   ["Removed from the playlist: #{entry.show_title}", :playing]
                 else
                   [entry.errors.full_messages.join(' '), :error]
                 end
    end

    # k/j move the selected entry one up/down, g/G to the top/bottom.
    def reorder_selected(key)
      entry = selected_item&.reload
      return unless entry

      target = { 'k' => entry.position - 1, 'j' => entry.position + 1, 'g' => 1, 'G' => @items[:left].size }[key]
      if entry.move_to(target)
        reload_data # the cursor follows the entry
      elsif entry.errors.any?
        @message = [entry.errors.full_messages.join(' '), :error]
      elsif target < entry.position && @playlist.reload.online?
        @message = ['The show that is playing stays at the top while the radio is online.', :highlight]
      end
    end

    def ask_shuffle
      return if @items[:left].size < 2

      note = @playlist.reload.online? ? ' The show that is playing stays first.' : ''
      ask("Shuffle the playlist?#{note}", 'shuffle') do
        @playlist.shuffle!
        reload_data
        @message = ['Shuffled the playlist.', :playing]
      end
    end

    def ask_delete
      show = selected_item
      if @active == :left
        @message = ['Only shows that are not on the playlist can be deleted. Remove it first.', :highlight]
      elsif show
        question = 'Delete "%s" and its songs from the database? Files are kept.'
        title = truncate(show.long_title, [@width - 4 - (question.length - 2) - ' [y/N]'.length, 10].max)
        ask(format(question, title), 'delete') { delete_show(show) }
      end
    end

    # Show +question+ with a [y/N] prompt; y runs the block.
    def ask(question, action, &block)
      @confirm = { question: "#{question} [y/N]", action: action, block: block }
    end

    # Any key other than y cancels; the periodic refresh and resizes don't count.
    def answer_confirm(key)
      return nil if key.nil? || key == Curses::KEY_RESIZE

      confirm = @confirm
      @confirm = nil
      if %w[y Y].include?(key)
        confirm[:block].call
      else
        @message = ["#{confirm[:action].capitalize} cancelled.", :label]
      end
      nil
    end

    def delete_show(show)
      @message = if show.destroy
                   ["Deleted from the database: #{show.long_title}", :playing]
                 else
                   [show.errors.full_messages.join(' '), :error]
                 end
      reload_data
    end

    # --- Drawing -------------------------------------------------------------

    def list_rows
      [@height - HEADER_ROWS - FOOTER_ROWS, 1].max
    end

    def draw_screen
      @split = @width / 2
      draw_frame(TITLE, [@height - 3])
      draw_header
      draw_panel_borders
      SIDES.each { |side| draw_panel(side) }
      draw_status
      draw_help(@height - 2, help_items)
    end

    def draw_header
      put(1, 2, 'Playlist:', :label)
      put(1, 12, @playlist.name, :highlight)
      col = 13 + @playlist.name.length
      put(1, col, @playlist.online? ? '● online' : '○ offline', @playlist.online? ? :playing : :label)

      total = "#{@items[:left].size} shows · #{format_length(@items[:left].sum { |entry| entry.show.length.to_i })}"
      put(1, @width - 2 - total.length, total, :label)
    end

    def draw_panel_borders
      horizontal_line(HEADER_ROWS - 1, '├', '┤')
      horizontal_line(@height - 5, '├', '┤')
      put(HEADER_ROWS - 1, @split, '┬', :border)
      put(@height - 5, @split, '┴', :border)
      (HEADER_ROWS...(HEADER_ROWS + list_rows)).each { |row| put(row, @split, '│', :border) }

      put(HEADER_ROWS - 1, 2, " On playlist (#{@items[:left].size}) ", @active == :left ? :title : :label)
      put(HEADER_ROWS - 1, @split + 2, " Not on playlist (#{@items[:right].size}) ",
          @active == :right ? :title : :label)
    end

    # Column and width of the inside of a panel.
    def panel_bounds(side)
      side == :left ? [1, @split - 1] : [@split + 1, @width - @split - 2]
    end

    def draw_panel(side)
      col, width = panel_bounds(side)
      return draw_empty_panel(side, col) if @items[side].empty?

      scroll_into_view(side)
      items = @items[side][@offset[side], list_rows]
      items.each_with_index do |item, index|
        draw_item(side, item, @offset[side] + index, HEADER_ROWS + index, col, width)
      end
      below = @items[side].size - @offset[side] - list_rows
      draw_scroll_hints(HEADER_ROWS, list_rows, col + width - 1, @offset[side], below)
    end

    def scroll_into_view(side)
      cursor = @cursor[side]
      @offset[side] = cursor if cursor < @offset[side]
      @offset[side] = cursor - list_rows + 1 if cursor >= @offset[side] + list_rows
      @offset[side] = @offset[side].clamp(0, [@items[side].size - list_rows, 0].max)
    end

    def draw_item(side, item, index, row, col, width)
      prefix, prefix_style = item_prefix(side, item, index)
      text_width = width - prefix.length - 1
      text_width -= SCROLL_HINT_WIDTH if scroll_hint_row?(side, index)
      text = truncate(show_of(item).long_title, text_width)

      if index == @cursor[side] && side == @active
        put(row, col, "#{prefix}#{text}".ljust(width), :cursor_selected)
      else
        put(row, col, prefix, prefix_style)
        put(row, col + prefix.length, text, index == @cursor[side] ? :cursor : nil)
      end
    end

    # Whether the item at +index+ shares its row with a "▲/▼ N more" hint.
    def scroll_hint_row?(side, index)
      (index == @offset[side] && @offset[side].positive?) ||
        (index == @offset[side] + list_rows - 1 && index < @items[side].size - 1)
    end

    # The "▶  1 " in front of a playlist entry, or just a margin for other shows.
    def item_prefix(side, item, index)
      return [' ', nil] if side == :right

      playing = index.zero? && @playlist.online?
      number = item.position.to_s.rjust(@items[:left].size.to_s.length)
      [" #{playing ? '▶' : ' '} #{number}  ", playing ? :playing : :number]
    end

    def draw_empty_panel(side, col)
      text = side == :left ? 'The playlist is empty.' : 'All shows are on the playlist.'
      put(HEADER_ROWS, col + 2, text, :label)
    end

    def draw_status
      row = @height - 4
      if @confirm
        put(row, 2, truncate(@confirm[:question], @width - 4), :error)
      elsif @message
        put(row, 2, truncate(@message[0], @width - 4), @message[1])
      end
    end

    def help_items
      return [['y', @confirm[:action]], ['any other key', 'cancel']] if @confirm

      if @active == :left
        [['Tab/←/→', 'side'], ['↑/↓', 'select'], ['Enter/l', 'remove'], %w[j/k move], ['g/G', 'top/bottom'],
         %w[s shuffle], %w[q quit]]
      else
        [['Tab/←/→', 'side'], ['↑/↓', 'select'], ['Enter/h', 'add'], %w[d delete], %w[s shuffle], %w[q quit]]
      end
    end

    def format_length(milliseconds)
      minutes = (milliseconds / 60_000).round
      "#{minutes / 60}h #{(minutes % 60).to_s.rjust(2, '0')}m"
    end
  end
end
