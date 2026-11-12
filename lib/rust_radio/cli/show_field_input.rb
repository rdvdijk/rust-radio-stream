# frozen_string_literal: true

require 'rust_radio/cli/text_input'

module RustRadio
  # A TextInput pop-up that edits one field of a show and saves it. The host
  # UI sends it every key while it's open, and shows #message, if any.
  class ShowFieldInput
    LABELS = { notes: 'Notes', setlist_identifier: 'Setlist ID' }.freeze
    # The show's date and its number on that day, as sugarmtn.org numbers them.
    SETLIST_IDENTIFIER = /\A\d{9}\z/
    SETLIST_IDENTIFIER_HINT = 'A setlist ID is the date and 0, 1 (early) or 2 (late), for example 197810220.'

    attr_reader :message

    def initialize(show, field)
      @show = show
      @field = field
      @text_input = TextInput.new(" #{LABELS[field]}: #{show.long_title} ", show[field])
    end

    # Returns :close when the input is done. An invalid value keeps it open,
    # so it can be corrected. Raises ActiveRecord errors from saving.
    def handle_key(key)
      case @text_input.handle_key(key)
      when :cancel then :close
      when :save then save
      end
    end

    def draw(screen)
      @text_input.draw(screen)
    end

    private

    def save
      @message = nil
      value = @text_input.text.presence
      if @field == :setlist_identifier && value && !value.match?(SETLIST_IDENTIFIER)
        @message = [SETLIST_IDENTIFIER_HINT, :error]
        return
      end

      @show.update!(@field => value)
      @message = ["#{LABELS[@field]} saved for #{@show.long_title}", :playing]
      :close
    end
  end
end
