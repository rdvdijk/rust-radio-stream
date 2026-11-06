# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'
require 'rust_radio/flac_details'

module RustRadio
  # Full-screen terminal UI that lists the FLAC files of a show folder, with
  # their tags, and asks the user to confirm adding it. #run returns :add or
  # :cancel.
  #
  # The tags most files share (artist, album, date) are shown once at the top;
  # a file only lists them when it differs.
  class AddShowUI < TerminalUI
    TITLE = ' Rust Radio · Add show '
    HELP = [['↑/↓', 'scroll'], ['←/→/Tab', 'select'], ['Enter', 'confirm'], ['q/Esc', 'cancel']].freeze
    BUTTON_LABELS = { add: 'Add show', cancel: 'Cancel', ok: 'OK' }.freeze
    TAG_LABELS = { 'ARTIST' => 'Artist', 'ALBUM' => 'Album', 'DATE' => 'Date' }.freeze

    # top border, folder, playlist, one row per common tag, list separator
    HEADER_ROWS = 4 + FlacDetails::COMMON_TAGS.size
    FOOTER_ROWS = 5 # separator, buttons, separator, help, bottom border
    MIN_HEIGHT = HEADER_ROWS + FOOTER_ROWS + 2
    LABEL_COL = 12 # where header values start

    TRACK_COL = 3 # track number
    FILE_COL = 7 # file name
    DETAIL_COL = 9 # title, differing tags and warnings under the file name

    # Characters that are normal in a song title: letters (also accented),
    # digits, spaces and common punctuation. Anything else is highlighted.
    EXPECTED_TITLE_CHARACTER = %r{[\p{L}\p{M}\p{Nd} ',.\-()!?:/’]}

    def initialize(folder_path, playlist_name, flac_files)
      super()
      @folder_path = folder_path
      @playlist_name = playlist_name
      @details = flac_files.map { |file| FlacDetails.new(folder_path, file) }
      @readable = @details.select(&:readable?)
      @defaults = FlacDetails::COMMON_TAGS.to_h { |tag| [tag, most_common(@readable.map { |flac| flac[tag] })] }
      build_lines
      @buttons = BUTTON_LABELS.slice(*(flac_files.empty? ? [:ok] : %i[add cancel]))
      @selected = 0
      @offset = 0
    end

    private

    # --- Data ----------------------------------------------------------------

    def most_common(values)
      values.tally.max_by { |_value, count| count }&.first
    end

    # The tags of +flac+ that differ from what most files have. An unreadable
    # file has no tags to compare; it only shows its warning.
    def differing_tags(flac)
      return [] unless flac.readable?

      FlacDetails::COMMON_TAGS.reject { |tag| flac[tag] == @defaults[tag] }
    end

    # Every file becomes a few lines. A line is a list of [col, text, style]
    # segments; col :duration is the length column, just after the longest
    # title. @file_starts holds the index
    # of each file's first line, for the "N more" hints.
    def build_lines
      @lines = []
      @file_starts = []
      @details.each do |flac|
        @file_starts << @lines.size
        @lines << file_line(flac)
        @lines << title_line(flac) if flac.title || flac.length
        @lines << differences_line(flac) if differing_tags(flac).any?
        flac.warnings.each { |warning| @lines << [[DETAIL_COL, "⚠ #{warning}", :error]] }
      end
    end

    def file_line(flac)
      track = flac.track_number
      [[TRACK_COL, track ? format('%02d', track) : '--', track ? :title : :label], [FILE_COL, flac.file, nil]]
    end

    def title_line(flac)
      line = flac.title ? title_segments(flac.title) : [[DETAIL_COL, '(no title)', :label]]
      line.push([:duration, format_duration(flac.length).rjust(duration_width), :label]) if flac.length
      line
    end

    # The title split into runs of expected and unexpected characters; the
    # unexpected ones are marked so they stand out.
    def title_segments(title)
      col = DETAIL_COL
      title.each_char.chunk { |char| char.match?(EXPECTED_TITLE_CHARACTER) }.map do |expected, chars|
        text = chars.join
        segment = [col, text, expected ? :value : :mark]
        col += text.length
        segment
      end
    end

    def title_width
      @title_width ||= @details.map { |flac| (flac.title || '(no title)').length }.max.to_i
    end

    def duration_width
      @duration_width ||= @details.map { |flac| flac.length ? format_duration(flac.length).length : 0 }.max.to_i
    end

    def differences_line(flac)
      col = DETAIL_COL
      differing_tags(flac).flat_map do |tag|
        label = "#{TAG_LABELS[tag]}: "
        value = flac[tag] || '(not set)'
        segments = [[col, label, :label], [col + label.length, value, :highlight]]
        col += label.length + value.length + 3
        segments
      end
    end

    # --- Input ---------------------------------------------------------------

    def handle_key(key)
      case key
      when *ENTER_KEYS then @buttons.keys[@selected] == :add ? :add : :cancel
      when *QUIT_KEYS then :cancel
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
      [@lines.size - list_rows, 0].max
    end

    # --- Drawing -------------------------------------------------------------

    def draw_screen
      @offset = @offset.clamp(0, max_offset)
      draw_frame(TITLE, [@height - 5, @height - 3])
      horizontal_line(HEADER_ROWS - 1, '├', '┤', list_title)
      draw_header
      @details.empty? ? draw_empty : draw_files
      draw_buttons(@height - 4, @buttons, @selected)
      draw_help(@height - 2, HELP)
    end

    def list_title
      total = @details.sum { |flac| flac.length.to_f }
      " FLAC files (#{@details.size})#{" · #{format_duration(total)}" if total.positive?} "
    end

    def draw_header
      value_width = @width - LABEL_COL - 2
      put(1, 2, 'Folder:', :label)
      put(1, LABEL_COL, truncate_left(@folder_path, value_width), :value)
      put(2, 2, 'Playlist:', :label)
      put(2, LABEL_COL, truncate(@playlist_name, value_width), :highlight)
      FlacDetails::COMMON_TAGS.each_with_index { |tag, index| draw_common_tag(3 + index, tag, value_width) }
    end

    # "Artist:  Neil Young   (2 of 14 differ)"
    def draw_common_tag(row, tag, width)
      differ = @readable.count { |flac| differing_tags(flac).include?(tag) }
      note = differ.positive? ? "  (#{differ} of #{@readable.size} differ)" : ''
      value = truncate(@defaults[tag] || '(not set)', width - note.length)

      put(row, 2, "#{TAG_LABELS[tag]}:", :label)
      put(row, LABEL_COL, value, @defaults[tag] ? :value : :label)
      put(row, LABEL_COL + value.length, note, :highlight)
    end

    def draw_files
      above = @file_starts.count { |start| start < @offset }
      below = @file_starts.count { |start| start >= @offset + list_rows }
      visible = @lines[@offset, list_rows]
      visible.each_with_index do |line, index|
        # Only the rows that carry a "N more" hint make room for it.
        hint = (index.zero? && above.positive?) || (index == list_rows - 1 && below.positive?)
        draw_line(HEADER_ROWS + index, line, @width - 2 - (hint ? SCROLL_HINT_WIDTH : 0))
      end
      draw_scroll_hints(HEADER_ROWS, list_rows, @width - 2, above, below)
    end

    # Draws the segments of a line, keeping all text left of +right_edge+. The
    # length goes in a column two spaces after the longest title, moved left
    # if the screen is too narrow; the title is then shortened to fit.
    def draw_line(row, line, right_edge)
      duration = line.find { |col, _text, _style| col == :duration }
      if duration
        duration_col = [DETAIL_COL + title_width + 2, right_edge - 1 - duration[1].length].min
        put(row, duration_col, duration[1], duration[2])
        right_edge = duration_col - 1
      end

      line.each do |col, text, style_name|
        next if col == :duration || col >= right_edge

        put(row, col, truncate(text, right_edge - col - 1), style_name)
      end
    end

    def draw_empty
      put(HEADER_ROWS + 1, 4, 'No FLAC files found in this folder.', :highlight)
    end

    def format_duration(milliseconds)
      seconds = (milliseconds / 1000).round
      hours, rest = seconds.divmod(3600)
      hours.positive? ? format('%d:%02d:%02d', hours, *rest.divmod(60)) : format('%d:%02d', *rest.divmod(60))
    end
  end
end
