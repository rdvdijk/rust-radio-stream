# frozen_string_literal: true

require 'faraday'
require 'json'

module RustRadio
  # Posts to the Facebook Page every time a new show starts.
  class FacebookPoster
    # Pinned so a Graph API upgrade on Facebook's side can't silently change
    # behaviour; bump when Facebook deprecates it.
    GRAPH_URL = 'https://graph.facebook.com/v27.0'
    LISTEN_URL = 'https://rustradio.org'

    def initialize(config)
      @disabled = config['disabled']
      @access_token = config['access_token']
    end

    def show_update(show)
      post(message_for(show))
    end

    def message_for(show)
      [
        "Now playing: #{show.long_title}",
        show.notes.to_s.strip.presence,
        "Listen now on #{LISTEN_URL}"
      ].compact.join("\n\n")
    end

    private

    # Posts in a new thread, to prevent blocking the streaming of data.
    def post(message)
      return if @disabled

      Thread.new do
        # With a Page access token, "me" is the Page itself.
        response = connection.post('me/feed', message:, access_token: @access_token)
        unless response.success?
          RustRadio.logger.error("Facebook post failed (#{response.status}): #{error_message(response)}")
        end
      rescue Faraday::Error => e
        RustRadio.logger.error("Facebook post failed: #{e.message}")
      end
    end

    def connection
      Faraday.new(url: "#{GRAPH_URL}/") do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    end

    def error_message(response)
      JSON.parse(response.body).dig('error', 'message') || response.body
    rescue JSON::ParserError
      response.body
    end
  end
end
