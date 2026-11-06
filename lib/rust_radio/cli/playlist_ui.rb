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
    SHUFFLE_KEYS = %w[s S].freeze
    # On the left these reorder the playlist; on the right they just move the cursor.
    REORDER_KEYS = %w[k j g G].freeze
    POPUP_MAX_WIDTH = 76

    def initialize(playlist)
      super()
      @playlist = playlist
      @active = :left
      @cursor = { left: 0, right: 0 }
      @offset = { left: 0, right: 0 }
      @items = { left: [], right: [] }
      @message = nil
      @confirm = nil
      @popup = nil
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

    # The periodic refresh, skipped while a prompt or pop-up is open.
    def on_idle(key)
      safely { reload_data } if key.nil? && !@confirm && !@popup
    end

    def safely
      yield
    rescue ActiveRecord::ActiveRecordError => e
      @message = ["Database error: #{e.message}", :error]
    end

    def error_message(record)
      [record.errors.full_messages.join(' '), :error]
    end

    # --- Data ----------------------------------------------------------------

    def reload_data
      selected_ids = SIDES.to_h { |side| [side, selected_item(side)&.id] }
      @playlist.reload
      @items = {
        left: @playlist.entries.includes(:show).to_a,
        right: Show.where.not(id: @playlist.shows.select(:id)).order(:date, :artist).to_a
      }
      SIDES.each { |side| restore_cursor(side, selected_ids[side]) }
    end

    # Keep the same item selected; if it's gone, stay at the same position.
    def restore_cursor(side, selected_id)
      index = @items[side].index { |item| item.id == selected_id }
      @cursor[side] = (index || @cursor[side]).clamp(0, last_index(@items[side].size))
    end

    def selected_item(side = @active)
      @items[side][@cursor[side]]
    end

    def show_of(item)
      item.is_a?(PlaylistEntry) ? item.show : item
    end

    # --- Input ---------------------------------------------------------------

    def handle_key(key)
      if @confirm
        answer_confirm(key)
      elsif @popup
        @popup = nil # any key closes the pop-up, without doing anything else
      elsif QUIT_KEYS.include?(key)
        return :quit
      else
        @message = nil
        safely { perform(key) }
      end
      nil
    end

    def perform(key)
      case key
      when 'r', 'R' then reload_data
      when *TAB_KEYS, Curses::KEY_BTAB then @active = @active == :left ? :right : :left
      when Curses::KEY_LEFT then @active = :left
      when Curses::KEY_RIGHT then @active = :right
      when *ENTER_KEYS then move_selected
      when ' ' then open_popup
      when 'l' then move_selected if @active == :left # left → right: remove from playlist
      when 'h' then move_selected if @active == :right # right → left: add to playlist
      when *REORDER_KEYS then @active == :left ? reorder_selected(key) : move_cursor(key)
      when *SHUFFLE_KEYS then ask_shuffle
      when *DELETE_KEYS then ask_delete
      else move_cursor(key)
      end
    end

    def move_cursor(key)
      cursor = @cursor[@active]
      last = last_index(@items[@active].size)
      target = case key
               when Curses::KEY_UP, 'k' then cursor - 1
               when Curses::KEY_DOWN, 'j' then cursor + 1
               when Curses::KEY_PPAGE then cursor - list_rows
               when Curses::KEY_NPAGE then cursor + list_rows
               when Curses::KEY_HOME, 'g' then 0
               when Curses::KEY_END, 'G' then last
               else return
               end
      @cursor[@active] = target.clamp(0, last)
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
      @message = entry.destroy ? ["Removed from the playlist: #{entry.show_title}", :playing] : error_message(entry)
    end

    # --- Show info pop-up ----------------------------------------------------

    # The details are collected once, when the pop-up opens.
    def open_popup
      item = selected_item
      return unless item

      show = show_of(item)
      @popup = { title: " #{show.artist} · #{show.date} ", rows: show_info(show) + entry_info(item) }
    end

    def show_info(show)
      [['Venue', show.venue], ['City', show.city_state], ['Festival', show.festival],
       ['Length', format_length(show.length.to_i)], ['Songs', show.songs.count.to_s],
       ['Folder', show.folder_path], ['Playlists', show.playlist_names.join(', ').presence || 'none'],
       ['Last played', show.last_played_at&.strftime('%Y-%m-%d %H:%M')],
       ['Added', show.created_at&.strftime('%Y-%m-%d')]].reject { |_label, value| value.blank? }
    end

    # Extra rows for a show on the playlist: its position, and what's playing.
    def entry_info(item)
      return [] unless item.is_a?(PlaylistEntry)

      rows = [['Position', "#{item.position} of #{@items[:left].size}"]]
      return rows unless item.position == 1

      song = item.song_to_play
      label = @playlist.online? ? 'Now playing' : 'Next song'
      rows << [label, "#{item.current_song + 1}/#{item.show.songs.size} #{song&.title}"]
    end

    # k/j move the selected entry one up/down, g/G to the top/bottom.
    def reorder_selected(key)
      entry = selected_item&.reload
      return unless entry

      target = { 'k' => entry.position - 1, 'j' => entry.position + 1, 'g' => 1, 'G' => @items[:left].size }[key]
      if entry.move_to(target)
        reload_data # the cursor follows the entry
      elsif entry.errors.any?
        @message = error_message(entry)
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

    # Any key other than y cancels.
    def answer_confirm(key)
      confirm = @confirm
      @confirm = nil
      if %w[y Y].include?(key)
        safely { confirm[:block].call }
      else
        @message = ["#{confirm[:action].capitalize} cancelled.", :label]
      end
    end

    def delete_show(show)
      @message = show.destroy ? ["Deleted from the database: #{show.long_title}", :playing] : error_message(show)
      reload_data
    end

    # --- Drawing -------------------------------------------------------------

    # The column of the line between the two panels.
    def split
      @width / 2
    end

    def draw_screen
      draw_frame(TITLE, [@height - 3])
      draw_header
      draw_panel_borders
      SIDES.each { |side| draw_panel(side) }
      draw_status
      draw_help(@height - 2, help_items)
      draw_popup if @popup
    end

    # A box centered on the screen, drawn over the panels.
    def draw_popup
      label_width = @popup[:rows].map { |label, _value| label.length }.max + 2
      longest = @popup[:rows].map { |label, value| label_width + value.length }.max
      max_width = [POPUP_MAX_WIDTH, @width - 4].min
      width = (longest + 4).clamp([@popup[:title].length + 6, max_width].min, max_width)
      height = [@popup[:rows].size + 4, @height - 2].min
      top = (@height - height) / 2
      left = (@width - width) / 2

      draw_box(top, left, width, height, @popup[:title])
      @popup[:rows].first(height - 4).each_with_index do |(label, value), index|
        draw_popup_row(top + 1 + index, left + 2, width - 4, label_width, label, value)
      end
      hint = 'press any key to close'
      put(top + height - 2, left + width - 2 - hint.length, hint, :help)
    end

    def draw_popup_row(row, col, width, label_width, label, value)
      value_width = width - label_width
      value = label == 'Folder' ? truncate_left(value, value_width) : truncate(value, value_width)
      put(row, col, label, :label)
      put(row, col + label_width, value, label == 'Now playing' ? :playing : :value)
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
      put(HEADER_ROWS - 1, split, '┬', :border)
      put(@height - 5, split, '┴', :border)
      (HEADER_ROWS...(HEADER_ROWS + list_rows)).each { |row| put(row, split, '│', :border) }

      put(HEADER_ROWS - 1, 2, " On playlist (#{@items[:left].size}) ", @active == :left ? :title : :label)
      put(HEADER_ROWS - 1, split + 2, " Not on playlist (#{@items[:right].size}) ",
          @active == :right ? :title : :label)
    end

    # Column and width of the inside of a panel.
    def panel_bounds(side)
      side == :left ? [1, split - 1] : [split + 1, @width - split - 2]
    end

    def draw_panel(side)
      col, width = panel_bounds(side)
      return draw_empty_panel(side, col) if @items[side].empty?

      scroll_into_view(side)
      above = @offset[side]
      below = @items[side].size - above - list_rows
      @items[side][above, list_rows].each_with_index do |item, index|
        draw_item(side, item, above + index, HEADER_ROWS + index, col, width,
                  hint: scroll_hint_row?(index, above, below))
      end
      draw_scroll_hints(HEADER_ROWS, col + width - 1, above, below)
    end

    def scroll_into_view(side)
      cursor = @cursor[side]
      @offset[side] = cursor if cursor < @offset[side]
      @offset[side] = cursor - list_rows + 1 if cursor >= @offset[side] + list_rows
      @offset[side] = @offset[side].clamp(0, [@items[side].size - list_rows, 0].max)
    end

    # +hint+: the row shares space with a "▲/▼ N more" hint.
    def draw_item(side, item, index, row, col, width, hint: false)
      prefix, prefix_style = item_prefix(side, item, index)
      text_width = width - prefix.length - 1 - (hint ? SCROLL_HINT_WIDTH : 0)
      text = truncate(show_of(item).long_title, text_width)

      if index == @cursor[side] && side == @active
        put(row, col, "#{prefix}#{text}".ljust(width), :cursor_selected)
      else
        put(row, col, prefix, prefix_style)
        put(row, col + prefix.length, text, index == @cursor[side] ? :cursor : nil)
      end
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
        [['Tab/←/→', 'side'], ['Enter/l', 'remove'], %w[j/k move], ['g/G', 'top/bottom'], %w[Space info],
         %w[s shuffle], %w[q quit]]
      else
        [['Tab/←/→', 'side'], ['Enter/h', 'add'], %w[Space info], %w[d delete], %w[s shuffle], %w[q quit]]
      end
    end

    def format_length(milliseconds)
      minutes = (milliseconds / 60_000).round
      "#{minutes / 60}h #{(minutes % 60).to_s.rjust(2, '0')}m"
    end
  end
end
