# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'
require 'rust_radio/cli/text_input'
require 'rust_radio/cli/show_info'
require 'rust_radio/cli/playlist_search'
require 'rust_radio/cli/playlist_panel'
require 'rust_radio/cli/song_list'

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
    # Keys that run an action whichever side is active.
    ACTIONS = {
      'r' => :reload_data, 'R' => :reload_data, ' ' => :open_popup, 'n' => :edit_notes, '/' => :start_search,
      'e' => :open_songs, 'E' => :open_songs,
      's' => :ask_shuffle, 'S' => :ask_shuffle, 'd' => :ask_delete, 'D' => :ask_delete, Curses::KEY_DC => :ask_delete
    }.freeze
    # On the left these reorder the playlist; on the right they just move the cursor.
    REORDER_KEYS = %w[k j g G].freeze
    # Space opens the info pop-up here, so it doesn't page.
    PAGE_DOWN_KEYS = (TerminalUI::PAGE_DOWN_KEYS - [' ']).freeze

    def initialize(playlist)
      super()
      @playlist = playlist
      @active = :left
      @cursor = { left: 0, right: 0 }
      @panels = SIDES.to_h { |side| [side, PlaylistPanel.new(side, self, method(:title_of))] }
      @items = { left: [], right: [] }
      @message = nil
      @confirm = nil
      @popup = nil
      @search = nil
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

    def on_idle(key)
      safely { reload_data } if key.nil? && !@confirm && !@popup && !@input && !@songs
    end

    def safely
      yield
    rescue ActiveRecord::ActiveRecordError => e
      @message = ["Database error: #{e.message}", :error]
    end

    def error_message(record)
      [record.errors.full_messages.join(' '), :error]
    end

    def reload_data
      selected_ids = SIDES.to_h { |side| [side, selected_item(side)&.id] }
      @playlist.reload
      @items = {
        left: @playlist.entries.includes(:show).to_a,
        right: Show.where.not(id: @playlist.shows.select(:id)).order(:date, :artist).to_a
      }
      SIDES.each { |side| restore_cursor(side, selected_ids[side]) }
      @search&.find(@items)
      @now_playing = now_playing
    end

    def now_playing
      entry = @items[:left].first
      return unless @playlist.online? && entry

      [entry.current_song + 1, entry.show.songs.size, entry.song_to_play&.title]
    end

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

    # The title shown, and searched, for an item on either side.
    def title_of(item)
      show_of(item).long_title
    end

    def handle_key(key)
      return if handled_by_overlay?(key)

      if @search && ESCAPE_KEYS.include?(key)
        @search = nil
      elsif ESCAPE_KEYS.include?(key)
        confirm_quit(:quit, 'Quit the playlist editor?')
      elsif QUIT_KEYS.include?(key)
        return :quit
      else
        @message = nil
        safely { perform(key) }
      end
      nil
    end

    # Sends +key+ to the open overlay, if any; returns whether there was one.
    def handled_by_overlay?(key)
      if @search&.typing? then search_key(key)
      elsif @input then answer_input(key)
      elsif @confirm then answer_confirm(key)
      elsif @songs then @songs = nil if @songs.handle_key(key, @height) == :close
      elsif @popup then @popup = nil
      else return false
      end
      true
    end

    def perform(key)
      return send(ACTIONS[key]) if ACTIONS.key?(key)

      case key
      when *TAB_KEYS, Curses::KEY_BTAB then @active = @active == :left ? :right : :left
      when Curses::KEY_LEFT then @active = :left
      when Curses::KEY_RIGHT then @active = :right
      when *ENTER_KEYS then move_selected
      when 'l' then move_selected if @active == :left # left → right: remove from playlist
      when 'h' then move_selected if @active == :right # right → left: add to playlist
      when *REORDER_KEYS then @active == :left ? reorder_selected(key) : move_cursor(key)
      else move_cursor(key)
      end
    end

    def move_cursor(key)
      cursor = @cursor[@active]
      last = last_index(@items[@active].size)
      target = case key
               when Curses::KEY_UP, 'k' then cursor - 1
               when Curses::KEY_DOWN, 'j' then cursor + 1
               when *PAGE_UP_KEYS then cursor - list_rows
               when *PAGE_DOWN_KEYS then cursor + list_rows
               when Curses::KEY_HOME, 'g' then 0
               when Curses::KEY_END, 'G' then last
               else return
               end
      @cursor[@active] = target.clamp(0, last)
    end

    def move_selected
      item = selected_item
      return unless item

      @active == :left ? remove_entry(item) : add_show(item)
      reload_data
    end

    def add_show(show)
      @playlist.entries.create!(show:)
      @message = ["Added to the playlist: #{show.long_title}", :playing]
    end

    def remove_entry(entry)
      @message = entry.destroy ? ["Removed from the playlist: #{entry.show_title}", :playing] : error_message(entry)
    end

    def open_popup
      item = selected_item
      return unless item

      show = show_of(item)
      @popup = { title: " #{show.artist} · #{show.date} ", rows: ShowInfo.rows(show) + entry_rows(item) }
    end

    def open_songs
      item = selected_item
      playing = item if item.is_a?(PlaylistEntry) && item.playing?
      @songs = SongList.new(show_of(item), playing_entry: playing) if item
    end

    def entry_rows(item)
      item.is_a?(PlaylistEntry) ? ShowInfo.entry_rows(item, @items[:left].size, @playlist.online?) : []
    end

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

    def edit_notes
      show = selected_item && show_of(selected_item)
      return unless show

      @input = TextInput.new(" Notes: #{show.long_title} ", show.notes)
      @input_show = show
    end

    def answer_input(key)
      result = @input.handle_key(key)
      if result == :save
        safely do
          @input_show.update!(notes: @input.text.presence)
          @message = ["Saved the notes for #{@input_show.long_title}", :playing]
        end
      end
      @input = nil if result
    end

    def start_search
      @search = PlaylistSearch.new { |item| title_of(item) }
    end

    # Selects the first match as the search is typed: on the playlist, or on
    # the other side if the playlist has none.
    def search_key(key)
      case @search.handle_key(key)
      when :cancel then @search = nil
      when :changed
        @search.find(@items)
        side, index = @search.first_match
        return unless side

        @active = side
        @cursor[side] = index
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
      @confirm = { question: "#{question} [y/N]", action:, block: }
    end

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
      draw_popup(@popup[:title], @popup[:rows], hint: 'press any key to close') if @popup
      @songs&.draw(self)
      @input&.draw(self)
    end

    def draw_header
      put(1, 2, 'Playlist:', :label)
      put(1, 12, @playlist.name, :highlight)
      col = 13 + @playlist.name.length
      status = @playlist.online? ? '● online' : '○ offline'
      put(1, col, status, @playlist.online? ? :playing : :label)

      length = ShowInfo.format_length(@items[:left].sum { |entry| entry.show.length.to_i })
      total = "#{@items[:left].size} shows · #{length}"
      put(1, @width - 2 - total.length, total, :label)
      draw_now_playing(col + status.length, @width - 4 - total.length) if @now_playing
    end

    def draw_now_playing(col, right)
      number, count, title = @now_playing
      position = " · #{number}/#{count} "
      put(1, col, truncate(position, right - col), :label)
      put(1, col + position.length, truncate(title.to_s, right - col - position.length), :value)
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
      view = PlaylistPanel::View.new(items: @items[side], cursor: @cursor[side], active: side == @active,
                                     playing: @playlist.online?, search: @search)
      @panels[side].draw(HEADER_ROWS, *panel_bounds(side), view)
    end

    def draw_status
      row = @height - 4
      if @confirm
        put(row, 2, truncate(@confirm[:question], @width - 4), :error)
      elsif @search && (@search.typing? || !@message)
        @search.draw(self, row)
      elsif @message
        put(row, 2, truncate(@message[0], @width - 4), @message[1])
      end
    end

    def help_items
      return [['y', @confirm[:action]], ['any other key', 'cancel']] if @confirm
      return PlaylistSearch::HELP if @search&.typing?

      if @active == :left
        [['Tab/←/→', 'side', 'Tab'], ['Enter/l', 'remove', 'l'], %w[j/k move], ['g/G', 'top/bottom'],
         %w[Space info], %w[e songs], %w[n notes], %w[/ search], %w[q quit], %w[s shuffle]]
      else
        [['Tab/←/→', 'side', 'Tab'], ['Enter/h', 'add', 'h'], %w[Space info], %w[e songs], %w[n notes], %w[/ search],
         %w[d delete], %w[q quit], %w[s shuffle]]
      end
    end
  end
end
