# frozen_string_literal: true

module RustRadio
  # The social media in the config file, which show updates and
  # announcements are posted to.
  class SocialMedia
    POSTERS = { 'facebook' => ['Facebook', FacebookPoster], 'bluesky' => ['Bluesky', BlueskyPoster] }.freeze

    # A section missing from the config leaves that medium out, with a
    # warning, so the radio still starts.
    def initialize(config)
      @posters = POSTERS.filter_map do |key, (name, poster_class)|
        next [name, poster_class.new(config[key])] if config[key]

        RustRadio.logger.warn("No '#{key}' section in the config, not posting to #{name}.")
        nil
      end.to_h
    end

    def show_update(show)
      @posters.each_value { it.show_update(show) }
    end

    # Returns the background posting threads by name. A thread's value is
    # whether posting worked.
    def announce(text)
      enabled.transform_values { it.announce(text) }
    end

    def enabled
      @posters.reject { |_name, poster| poster.disabled? }
    end

    def disabled_names
      @posters.keys - enabled.keys
    end
  end
end
