# frozen_string_literal: true

require 'date'
require 'faraday'
require 'json'

module RustRadio
  # Posts to the Facebook Page every time a new show starts.
  class FacebookPoster
    # Pinned so a Graph API upgrade on Facebook's side can't silently change
    # behaviour; bump when Facebook deprecates it.
    GRAPH_URL = 'https://graph.facebook.com/v27.0'
    LISTEN_URL = 'https://rustradio.org'
    BIRTHDAY_GREETING = 'Happy birthday, Neil!'
    BIRTHDAY_COMMENT = "\u{1F973}"

    def initialize(config)
      @disabled = config['disabled']
      @access_token = config['access_token']
    end

    def show_update(show)
      post(message_for(show), comment: (BIRTHDAY_COMMENT if neils_birthday?))
    end

    def message_for(show)
      [
        (BIRTHDAY_GREETING if neils_birthday?),
        "Now playing: #{show.long_title}",
        show.notes.to_s.strip.presence,
        "Listen now on #{LISTEN_URL}"
      ].compact.join("\n\n")
    end

    def neils_birthday?(date = Date.today)
      date.month == 11 && date.day == 12
    end

    private

    # Posts in a new thread, to prevent blocking the streaming of data.
    def post(message, comment: nil)
      return if @disabled

      Thread.new do
        # With a Page access token, "me" is the Page itself.
        response = connection.post('me/feed', message:, access_token: @access_token)
        if response.success?
          post_comment(JSON.parse(response.body)['id'], comment) if comment
        else
          RustRadio.logger.error("Facebook post failed (#{response.status}): #{error_message(response)}")
        end
      rescue Faraday::Error, JSON::ParserError => e
        RustRadio.logger.error("Facebook post failed: #{e.message}")
      end
    end

    def post_comment(post_id, message)
      response = connection.post("#{post_id}/comments", message:, access_token: @access_token)
      return if response.success?

      RustRadio.logger.error("Facebook comment failed (#{response.status}): #{error_message(response)}")
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
