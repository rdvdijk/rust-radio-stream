# frozen_string_literal: true

require 'rust_radio/cli/terminal_ui'

module RustRadio
  # A pop-up for reading the text files in a show folder (the info file,
  # checksums, taper notes): the files on the left, the selected file on the
  # right. The host UI sends it keys while it's open and calls #draw at the
  # end of its own drawing.
  class TextViewer
    TEXT_EXTENSIONS = %w[.txt .nfo .log .md5 .ffp .st5 .cue .sfv].freeze
    MAX_BYTES = 1_000_000
    TAB_WIDTH = 8
    HELP = [['↑/↓', 'select/scroll'], ['Tab/←/→', 'files/text'], ['f/b', 'page'], %w[Esc close]].freeze

    # +info_file+ is labelled "(info)" and listed first, so it's shown when
    # the viewer opens; the other files follow by name. +close_keys+ close
    # the viewer, besides Esc and q.
    def initialize(folder_path, info_file: nil, close_keys: [])
      @folder_path = folder_path
      @info_file = info_file
      @close_keys = [*TerminalUI::QUIT_KEYS, *close_keys]
      @files = text_files.sort_by { |file| [file == info_file ? 0 : 1, file] }
      @focus = :files
      @cursor = 0
      @offset = 0
      @scroll = 0
      @texts = {}
    end

    # Returns :close when the viewer should close. +screen_height+ sets the
    # page size.
    def handle_key(key, screen_height)
      return :close if @close_keys.include?(key)

      case key
      when *TerminalUI::TAB_KEYS, Curses::KEY_BTAB then @focus = @focus == :files ? :text : :files
      when Curses::KEY_LEFT then @focus = :files
      when Curses::KEY_RIGHT, *TerminalUI::ENTER_KEYS then @focus = :text
      else move(key, [rows(screen_height) - 1, 1].max)
      end
      nil
    end

    # The box starts at row 1, column 1: just inside the screen's frame, so the
    # frame's separators don't show around it.
    def draw(screen)
      width = screen.width - 2
      rows = rows(screen.height)
      split = 2 + files_width(width)

      screen.draw_box(1, 1, width, screen.height - 2, ' Text files ')
      (2..rows + 2).each { |row| screen.put(row, split, '│', :title) }
      draw_files(screen, 2, 2, split - 2, rows)
      draw_text(screen, 2, split + 2, width - 1 - (split + 2), rows)
      screen.draw_help(screen.height - 3, HELP, col: 3, right: width - 1)
    end

    private

    def files_width(box_width)
      [[(@files.map(&:length).max || 0) + 10, 16].max, box_width / 3].min
    end

    def text_files
      Dir.children(@folder_path).select do |file|
        TEXT_EXTENSIONS.include?(File.extname(file).downcase) && File.file?(File.join(@folder_path, file))
      end
    end

    # Rows for the panes: the box is two rows smaller than the screen, and
    # inside it are the pane titles and the help line.
    def rows(screen_height)
      screen_height - 6
    end

    def move(key, page)
      case key
      when Curses::KEY_UP, 'k' then step(-1)
      when Curses::KEY_DOWN, 'j' then step(1)
      when *TerminalUI::PAGE_UP_KEYS then step(-page)
      when *TerminalUI::PAGE_DOWN_KEYS then step(page)
      when Curses::KEY_HOME then @focus == :files ? select_file(0) : @scroll = 0
      when Curses::KEY_END then @focus == :files ? select_file(@files.size - 1) : @scroll = Float::INFINITY
      end
    end

    # The text's upper scroll bound depends on the wrapped lines, so #draw_text applies it.
    def step(lines)
      @focus == :files ? select_file(@cursor + lines) : @scroll = [@scroll + lines, 0].max
    end

    def select_file(index)
      index = index.clamp(0, [@files.size - 1, 0].max)
      @scroll = 0 unless index == @cursor
      @cursor = index
    end

    def text_lines(file)
      @texts[file] ||= read_text(File.join(@folder_path, file))
    end

    def read_text(path)
      text = decode(File.binread(path, MAX_BYTES) || '')
      text.delete_prefix("\uFEFF").gsub(/\r\n?/, "\n").split("\n").map { |line| clean_line(line) }
    rescue SystemCallError => e
      ["Can't read this file: #{e.message}"]
    end

    # UTF-8 if it is; otherwise most likely an old Windows text file. A file
    # cut off at MAX_BYTES may end in half a UTF-8 character, which is scrubbed.
    def decode(data)
      text = data.dup.force_encoding(Encoding::UTF_8)
      return text if text.valid_encoding?
      return text.scrub('?') if data.bytesize >= MAX_BYTES

      data.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    def clean_line(line)
      line = expand_tabs(line) if line.include?("\t")
      line.gsub(/[[:cntrl:]]/, '?')
    end

    def expand_tabs(line)
      line.each_char.with_object(+'') do |char, out|
        out << (char == "\t" ? ' ' * (TAB_WIDTH - (out.length % TAB_WIDTH)) : char)
      end
    end

    # +file+'s lines word-wrapped to +width+, cached for the last file and
    # width. Words longer than the width are cut when drawn.
    def wrapped_lines(file, width)
      return @wrapped[2] if @wrapped && @wrapped[0, 2] == [file, width]

      pattern = /(.{1,#{width}})(\s+|\z)/
      lines = text_lines(file).flat_map do |line|
        wrapped = line.gsub(pattern, "\\1\n").split("\n")
        wrapped.empty? ? [''] : wrapped
      end
      @wrapped = [file, width, lines]
      lines
    end

    def draw_files(screen, row, col, width, rows)
      screen.put(row, col + 1, 'Files', @focus == :files ? :title : :label)
      return screen.put(row + 2, col + 1, '(none)', :label) if @files.empty?

      @offset = @cursor - rows + 1 if @cursor >= @offset + rows
      @offset = @cursor if @cursor < @offset
      @files[@offset, rows].each_with_index do |file, index|
        draw_file(screen, row + 1 + index, col, width, file, @offset + index == @cursor)
      end
    end

    def draw_file(screen, row, col, width, file, selected)
      label = file == @info_file ? ' (info)' : ''
      text = " #{screen.truncate(file, width - 2 - label.length)}#{label}"
      if selected
        screen.put(row, col, text.ljust(width), @focus == :files ? :cursor_selected : :cursor)
      else
        screen.put(row, col, text)
        screen.put(row, col + text.length - label.length, label, :label) unless label.empty?
      end
    end

    def draw_text(screen, row, col, width, rows)
      file = @files[@cursor]
      return screen.put(row + 2, col, 'No text files in this folder.', :highlight) unless file

      lines = wrapped_lines(file, width)
      @scroll = @scroll.clamp(0, [lines.size - rows, 0].max).to_i
      draw_text_title(screen, row, col, width, file, lines.size > rows ? position(lines.size, rows) : '')
      return screen.put(row + 2, col, '(empty file)', :label) if lines.all?(&:empty?)

      lines[@scroll, rows].each_with_index do |line, index|
        screen.put(row + 1 + index, col, screen.truncate(line, width))
      end
    end

    # The file name, with "lines 12–30 of 85" at the right if it scrolls.
    def draw_text_title(screen, row, col, width, file, position)
      screen.put(row, col, screen.truncate(file, width - position.length), @focus == :text ? :title : :label)
      screen.put(row, col + width - position.length, position, :label)
    end

    def position(line_count, rows)
      "  lines #{@scroll + 1}–#{[@scroll + rows, line_count].min} of #{line_count}"
    end
  end
end
