# frozen_string_literal: true

module RustRadio
  # Completes the last part of a folder path, like a shell: the first Tab
  # extends it as far as all matching folders agree, and the next ones cycle
  # through the matches. A single match gets a trailing slash, so the next
  # Tab completes inside it.
  class FolderCompleter
    attr_reader :matches, :index

    # Returns the completed text, or nil if no folder matches. +step+ is 1
    # to cycle forward, -1 to cycle back.
    def complete(text, step = 1)
      return cycle(step) if text == @completed && @matches.size > 1

      start(text)
    end

    private

    def start(text)
      dir, prefix = split(text)
      @matches = folders(dir, prefix).map { "#{dir}#{it}" }
      @index = nil
      return @completed = nil if @matches.empty?
      return @completed = "#{@matches.first}/" if @matches.one?

      common = common_prefix(@matches)
      common.length > text.length ? @completed = common : cycle(1)
    end

    def cycle(step)
      @index = if @index then (@index + step) % @matches.size
               elsif step.positive? then 0
               else @matches.size - 1
               end
      @completed = @matches[@index]
    end

    # "~/music/ny19" → ["~/music/", "ny19"]. The folder part is kept as typed,
    # so a ~ or relative path stays that way in the text.
    def split(text)
      slash = text.rindex('/')
      slash ? [text[0..slash], text[(slash + 1)..]] : ['', text]
    end

    # Hidden folders only match when the typed name starts with a dot.
    def folders(dir, prefix)
      path = File.expand_path(dir.empty? ? '.' : dir)
      Dir.children(path).select do |name|
        name.start_with?(prefix) && (prefix.start_with?('.') || !name.start_with?('.')) &&
          File.directory?(File.join(path, name))
      end.sort
    rescue SystemCallError
      []
    end

    def common_prefix(strings)
      first, *rest = strings
      length = (0...first.length).find { |index| rest.any? { it[index] != first[index] } } || first.length
      first[0, length]
    end
  end
end
