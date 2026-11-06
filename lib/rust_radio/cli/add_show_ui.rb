# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'
require 'rust_radio/flac_details'
require 'rust_radio/show_adder'
require 'rust_radio/cli/text_viewer'
require 'rust_radio/cli/text_input'

module RustRadio
  # Full-screen terminal UI that lists the FLAC files of a show folder, with
  # their tags, and asks the user to confirm adding it. #run returns :add or
  # :cancel.
  #
  # The tags most files share (artist, album, date) are shown once at the top;
  # a file only lists them when it differs.
  class AddShowUI < TerminalUI
    TITLE = ' Rust Radio · Add show '
    # Items that don't fit are left out from the end, so the least needed comes last.
    HELP = [['↑/↓', 'scroll'], ['←/→/Tab', 'select', 'Tab'], %w[Enter confirm], %w[n note], %w[t texts],
            ['q/Esc', 'cancel', 'q'], ['f/b', 'page']].freeze
    TEXT_VIEWER_KEY = 't'
    NOTES_KEY = 'n'
    BUTTON_LABELS = { add: 'Add show', cancel: 'Cancel', ok: 'OK' }.freeze
    TAG_LABELS = { 'ARTIST' => 'Artist', 'ALBUM' => 'Album', 'DATE' => 'Date' }.freeze
    EXISTING_MESSAGE = ['This show is already in the database,', "and can't be added a second time."].freeze

    # top border, folder, playlist, one row per common tag, list separator
    HEADER_ROWS = 5 + FlacDetails::COMMON_TAGS.size
    FOOTER_ROWS = 5 # separator, buttons, separator, help, bottom border
    MIN_HEIGHT = HEADER_ROWS + FOOTER_ROWS + 2
    LABEL_COL = 12

    TRACK_COL = 3
    FILE_COL = 7
    DETAIL_COL = 9 # title, differing tags and warnings under the file name

    # Characters that are normal in a song title: letters (also accented),
    # digits, spaces and common punctuation. Anything else is highlighted.
    EXPECTED_TITLE_CHARACTER = %r{[\p{L}\p{M}\p{Nd} ',.\-()!?:/’]}

    # +existing_show+: the Show already added from this folder, if any. The
    # screen then explains that it can't be added again and only offers OK.
    #
    # +year_count+: [year, number of shows from that year already in the
    # database], or nil if the show's date is unknown.
    def initialize(folder_path, playlist_name, flac_files, existing_show: nil, year_count: nil)
      super()
      @year_count = year_count
      @existing = existing_show && existing_summary(existing_show)
      @notes = existing_show&.notes
      @folder_path = folder_path
      @playlist_name = playlist_name
      @details = flac_files.map { |file| FlacDetails.new(folder_path, file) }
      @readable = @details.select(&:readable?)
      summarize_tags
      @total_length = @details.sum { |flac| flac.length.to_f }
      build_lines
      @buttons = BUTTON_LABELS.slice(*(flac_files.empty? || @existing ? [:ok] : %i[add cancel]))
      @selected = 0
      @offset = 0
    end

    # The note typed for the show, for example why it's added; nil if none.
    attr_reader :notes

    private

    def existing_summary(show)
      [['Show', show.long_title],
       ['Added', show.created_at&.localtime&.strftime('%Y-%m-%d %H:%M') || 'unknown'],
       ['Playlists', show.playlist_summary]]
    end

    # [[text, style], ...] → segments placed one after another from +col+.
    def segments(col, parts)
      parts.map do |text, style|
        segment = [col, text, style]
        col += text.length
        segment
      end
    end

    # The value most files have for each common tag, and how many files differ.
    def summarize_tags
      @defaults = FlacDetails::COMMON_TAGS.to_h { |tag| [tag, most_common(@readable.map { |flac| flac[tag] })] }
      @differ_counts = FlacDetails::COMMON_TAGS.to_h do |tag|
        [tag, @readable.count { |flac| differing_tags(flac).include?(tag) }]
      end
    end

    def most_common(values)
      values.tally.max_by { |_value, count| count }&.first
    end

    def differing_tags(flac)
      return [] unless flac.readable?

      FlacDetails::COMMON_TAGS.reject { |tag| flac[tag] == @defaults[tag] }
    end

    # Every file becomes a few lines. A line is a list of [col, text, style]
    # segments; col :duration is the length column, just after the longest
    # title. @file_starts holds the index of each file's first line, for the
    # "N more" hints.
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

    def title_segments(title)
      runs = title.each_char.chunk { |char| char.match?(EXPECTED_TITLE_CHARACTER) }
      segments(DETAIL_COL, runs.map { |expected, chars| [chars.join, expected ? :value : :mark] })
    end

    def title_width
      @title_width ||= @details.map { |flac| (flac.title || '(no title)').length }.max.to_i
    end

    def duration_width
      @duration_width ||= @details.map { |flac| flac.length ? format_duration(flac.length).length : 0 }.max.to_i
    end

    # "Artist: Crazy Horse   Album: Encore"
    def differences_line(flac)
      parts = differing_tags(flac).each_with_index.flat_map do |tag, index|
        [*([['   ', nil]] unless index.zero?), ["#{TAG_LABELS[tag]}: ", :label], [flac[tag] || '(not set)', :highlight]]
      end
      segments(DETAIL_COL, parts)
    end

    # While the show is already added, only OK is offered, so Enter cancels
    # too; the file list behind the pop-up doesn't scroll.
    def handle_key(key)
      return handle_overlay_key(key) if @viewer || @input

      case key
      when TEXT_VIEWER_KEY then open_text_viewer
      when NOTES_KEY then @input = TextInput.new(' Notes: why this show is added ', @notes) unless @existing
      when *ENTER_KEYS then return @buttons.keys[@selected] == :add ? :add : :cancel
      when *QUIT_KEYS then return :cancel
      else navigate(key) unless @existing
      end
      nil
    end

    def handle_overlay_key(key)
      if @viewer
        @viewer = nil if @viewer.handle_key(key, @height) == :close
      else
        result = @input.handle_key(key)
        @notes = @input.text.presence if result == :save
        @input = nil if result
      end
      nil
    end

    def open_text_viewer
      @viewer = TextViewer.new(@folder_path, info_file: ShowAdder.info_file(@folder_path),
                                             close_keys: [TEXT_VIEWER_KEY])
    end

    def navigate(key)
      case key
      when Curses::KEY_UP then scroll_by(-1)
      when Curses::KEY_DOWN then scroll_by(1)
      when *PAGE_UP_KEYS then scroll_by(-list_rows)
      when *PAGE_DOWN_KEYS then scroll_by(list_rows)
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

    def max_offset
      [@lines.size - list_rows, 0].max
    end

    def draw_screen
      @offset = @offset.clamp(0, max_offset)
      draw_frame(TITLE, [@height - 5, @height - 3])
      horizontal_line(HEADER_ROWS - 1, '├', '┤', list_title)
      draw_header
      @details.empty? ? draw_empty : draw_files
      draw_buttons(@height - 4, @buttons, @selected)
      draw_help(@height - 2, @existing ? [['Enter/q', 'close'], ['t', 'text files']] : HELP)
      draw_popup(' Already added ', @existing, message: EXISTING_MESSAGE, style: :error) if @existing
      @viewer&.draw(self)
      @input&.draw(self)
    end

    def list_title
      " FLAC files (#{@details.size})#{" · #{format_duration(@total_length)}" if @total_length.positive?} "
    end

    def draw_header
      value_width = @width - LABEL_COL - 2
      put(1, 2, 'Folder:', :label)
      put(1, LABEL_COL, truncate_left(@folder_path, value_width), :value)
      put(2, 2, 'Playlist:', :label)
      put(2, LABEL_COL, truncate(@playlist_name, value_width), :highlight)
      draw_notes(3, value_width)
      FlacDetails::COMMON_TAGS.each_with_index { |tag, index| draw_common_tag(4 + index, tag, value_width) }
    end

    def draw_notes(row, width)
      put(row, 2, 'Notes:', :label)
      return put(row, LABEL_COL, truncate(@notes, width), :value) if @notes

      put(row, LABEL_COL, @existing ? '(none)' : '(none yet; press n to add why this show is added)', :label)
    end

    # "Artist:  Neil Young   (2 of 14 differ)"
    def draw_common_tag(row, tag, width)
      differ = @differ_counts[tag]
      note = differ.positive? ? "  (#{differ} of #{@readable.size} differ)" : ''
      value = truncate(@defaults[tag] || '(not set)', width - note.length)

      put(row, 2, "#{TAG_LABELS[tag]}:", :label)
      put(row, LABEL_COL, value, @defaults[tag] ? :value : :label)
      put(row, LABEL_COL + value.length, note, :highlight)
      draw_line(row, year_segments(LABEL_COL + value.length + note.length), @width - 1) if tag == 'DATE'
    end

    # " · 3 shows from 2016 already in the database", starting at +col+. The
    # year is the one in the info file, which is the date the show is saved with.
    def year_segments(col)
      return segments(col, [[' · year unknown (no date in the info file)', :label]]) unless @year_count

      year, count = @year_count
      parts = if count.zero?
                [["no shows from #{year} in the database yet", :playing]]
              else
                [["#{count} #{count == 1 ? 'show' : 'shows'}", :highlight],
                 [" from #{year} already in the database", :label]]
              end
      segments(col, [[' · ', :label], *parts])
    end

    def draw_files
      above = @file_starts.count { |start| start < @offset }
      below = @file_starts.count { |start| start >= @offset + list_rows }
      @lines[@offset, list_rows].each_with_index do |line, index|
        hint_width = scroll_hint_row?(index, above, below) ? SCROLL_HINT_WIDTH : 0
        draw_line(HEADER_ROWS + index, line, @width - 2 - hint_width)
      end
      draw_scroll_hints(HEADER_ROWS, @width - 2, above, below)
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
      hours, rest = (milliseconds / 1000).round.divmod(3600)
      minutes, seconds = rest.divmod(60)
      return format('%<minutes>d:%<seconds>02d', minutes:, seconds:) unless hours.positive?

      format('%<hours>d:%<minutes>02d:%<seconds>02d', hours:, minutes:, seconds:)
    end
  end
end
