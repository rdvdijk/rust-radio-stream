# frozen_string_literal: true

module RustRadio
  # A pop-up for reading the text files in a show folder (the info file,
  # checksums, taper notes): the files on the left, the selected file on the
  # right. Mixed into a TerminalUI, whose drawing helpers it uses.
  #
  # The including class calls #open_text_viewer, sends keys to
  # #text_viewer_key while #text_viewer_open?, and calls #draw_text_viewer
  # at the end of its #draw_screen.
  module TextViewer
    TEXT_EXTENSIONS = %w[.txt .nfo .log .md5 .ffp .st5 .cue .sfv].freeze
    MAX_BYTES = 1_000_000 # read at most this much of a file
    TAB_WIDTH = 8
    CLOSE_KEYS = [*TerminalUI::ESCAPE_KEYS, 'q', 'Q', 't'].freeze
    VIEWER_HELP = [['↑/↓', 'select/scroll'], ['Tab/←/→', 'files/text'], ['f/b', 'page'],
                   %w[Esc close]].freeze

    private

    # +info_file+ is labelled "(info)" and listed first, so it's shown when
    # the viewer opens; the other files follow by name.
    def open_text_viewer(folder_path, info_file: nil)
      files = Dir.children(folder_path).select do |file|
        TEXT_EXTENSIONS.include?(File.extname(file).downcase) && File.file?(File.join(folder_path, file))
      end
      files = files.sort_by { |file| [file == info_file ? 0 : 1, file] }
      @viewer = { folder: folder_path, files: files, info_file: info_file, focus: :files,
                  cursor: 0, offset: 0, scroll: 0, page: 1, texts: {} }
    end

    def text_viewer_open?
      !@viewer.nil?
    end

    # --- Input ---------------------------------------------------------------

    def text_viewer_key(key)
      viewer = @viewer
      case key
      when *CLOSE_KEYS then @viewer = nil
      when *TerminalUI::TAB_KEYS, Curses::KEY_BTAB then viewer[:focus] = viewer[:focus] == :files ? :text : :files
      when Curses::KEY_LEFT then viewer[:focus] = :files
      when Curses::KEY_RIGHT, *TerminalUI::ENTER_KEYS then viewer[:focus] = :text
      else viewer_move(key)
      end
      nil
    end

    # Moves the file selection or scrolls the text, whichever has the focus.
    def viewer_move(key)
      viewer = @viewer
      step = case key
             when Curses::KEY_UP, 'k' then -1
             when Curses::KEY_DOWN, 'j' then 1
             when *TerminalUI::PAGE_UP_KEYS then -viewer[:page]
             when *TerminalUI::PAGE_DOWN_KEYS then viewer[:page]
             when Curses::KEY_HOME then -Float::INFINITY
             when Curses::KEY_END then Float::INFINITY
             end
      return unless step

      if viewer[:focus] == :files
        cursor = (viewer[:cursor] + step).clamp(0, last_index(viewer[:files].size)).to_i
        viewer[:scroll] = 0 unless cursor == viewer[:cursor]
        viewer[:cursor] = cursor
      else
        # The upper bound depends on the wrapped text, so it's applied when drawing.
        viewer[:scroll] = (viewer[:scroll] + step).clamp(0, 1_000_000_000).to_i
      end
    end

    # --- Reading -------------------------------------------------------------

    # The lines of +file+, decoded and with tabs expanded; cached.
    def text_lines(file)
      @viewer[:texts][file] ||= read_text(File.join(@viewer[:folder], file))
    end

    def read_text(path)
      data = File.binread(path, MAX_BYTES) || ''
      text = data.dup.force_encoding(Encoding::UTF_8)
      # Not UTF-8: most likely an old Windows text file. A file cut off at
      # MAX_BYTES may end in half a UTF-8 character; scrub that instead.
      text = if text.valid_encoding? then text
             elsif data.bytesize < MAX_BYTES
               data.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace,
                                                                                    undef: :replace)
             else text.scrub('?')
             end
      text.delete_prefix("\uFEFF").gsub(/\r\n?/, "\n").split("\n").map { |line| clean_line(line) }
    rescue SystemCallError => e
      ["Can't read this file: #{e.message}"]
    end

    def clean_line(line)
      expanded = line.each_char.with_object(+'') do |char, out|
        out << (char == "\t" ? ' ' * (TAB_WIDTH - (out.length % TAB_WIDTH)) : char)
      end
      expanded.gsub(/[[:cntrl:]]/, '?')
    end

    # Word-wraps +lines+ to +width+; words longer than that are cut later.
    def wrap(lines, width)
      lines.flat_map do |line|
        wrapped = line.gsub(/(.{1,#{width}})(\s+|\z)/, "\\1\n").split("\n")
        wrapped.empty? ? [''] : wrapped
      end
    end

    # --- Drawing -------------------------------------------------------------

    def draw_text_viewer
      # Just inside the screen's frame, so its separators don't show around the box.
      top = 1
      left = 1
      width = @width - 2
      height = @height - 2
      rows = height - 4 # inside the box: pane titles, the panes, the help line
      files_width = [[(@viewer[:files].map(&:length).max || 0) + 10, 16].max, width / 3].min
      split = left + 1 + files_width
      @viewer[:page] = [rows - 1, 1].max

      draw_box(top, left, width, height, ' Text files ')
      (top + 1..top + rows + 1).each { |row| put(row, split, '│', :title) }
      draw_viewer_files(top + 1, left + 1, files_width, rows)
      draw_viewer_text(top + 1, split + 2, left + width - 2 - (split + 2), rows)
      draw_help(top + height - 2, VIEWER_HELP, col: left + 2, right: left + width - 2)
    end

    def draw_viewer_files(row, col, width, rows)
      viewer = @viewer
      put(row, col + 1, 'Files', viewer[:focus] == :files ? :title : :label)
      return put(row + 2, col + 1, '(none)', :label) if viewer[:files].empty?

      viewer[:offset] = viewer[:cursor] - rows + 1 if viewer[:cursor] >= viewer[:offset] + rows
      viewer[:offset] = viewer[:cursor] if viewer[:cursor] < viewer[:offset]
      viewer[:files][viewer[:offset], rows].each_with_index do |file, index|
        draw_viewer_file(row + 1 + index, col, width, file, viewer[:offset] + index == viewer[:cursor])
      end
    end

    def draw_viewer_file(row, col, width, file, selected)
      label = file == @viewer[:info_file] ? ' (info)' : ''
      text = " #{truncate(file, width - 2 - label.length)}#{label}"
      if selected
        put(row, col, text.ljust(width), @viewer[:focus] == :files ? :cursor_selected : :cursor)
      else
        put(row, col, text)
        put(row, col + text.length - label.length, label, :label) unless label.empty?
      end
    end

    def draw_viewer_text(row, col, width, rows)
      file = @viewer[:files][@viewer[:cursor]]
      return put(row + 2, col, 'No text files in this folder.', :highlight) unless file

      lines = wrap(text_lines(file), width)
      @viewer[:scroll] = @viewer[:scroll].clamp(0, [lines.size - rows, 0].max)
      first = @viewer[:scroll]
      position = lines.size > rows ? "  lines #{first + 1}–#{[first + rows, lines.size].min} of #{lines.size}" : ''

      put(row, col, truncate(file, width - position.length), @viewer[:focus] == :text ? :title : :label)
      put(row, col + width - position.length, position, :label)
      return put(row + 2, col, '(empty file)', :label) if lines.all?(&:empty?)

      lines[first, rows].each_with_index { |line, index| put(row + 1 + index, col, truncate(line, width)) }
    end
  end
end
