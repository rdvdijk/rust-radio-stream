# frozen_string_literal: true

require 'date'
require 'faraday'
require 'time'

module RustRadio
  # Posts to Bluesky every time a new show starts. Logs in with an app
  # password for every post: there are only a few posts a day, which keeps
  # far below the login rate limit and needs no token refreshing.
  class BlueskyPoster
    SERVICE_URL = 'https://bsky.social'
    LISTEN_URL = 'https://rustradio.org'
    BIRTHDAY_GREETING = 'Happy birthday, Neil!'
    # Bluesky's limit, counted in graphemes: what a reader sees as one
    # character, so an emoji with modifiers counts once.
    MAX_LENGTH = 300
    ELLIPSIS = '…'
    SEPARATOR = "\n\n"

    def initialize(config)
      @disabled = config['disabled']
      @handle = config['handle']
      @app_password = config['app_password']
    end

    def show_update(show)
      post(message_for(show))
    end

    # The notes come last and are shortened to fit, so the title and the
    # link are always in the post.
    def message_for(show)
      head = [
        (BIRTHDAY_GREETING if neils_birthday?),
        "Now playing: #{show.long_title}",
        "Listen now on #{LISTEN_URL}"
      ].compact.join(SEPARATOR)
      notes = fit(show.notes.to_s.strip, MAX_LENGTH - graphemes(head + SEPARATOR))
      notes.empty? ? head : "#{head}#{SEPARATOR}#{notes}"
    end

    # Bluesky doesn't turn URLs in the text into links: a facet marks the
    # link, by its UTF-8 byte offsets, not character offsets.
    def link_facets(text)
      start = text.byteindex(LISTEN_URL)
      return [] unless start

      [{ index: { byteStart: start, byteEnd: start + LISTEN_URL.bytesize },
         features: [{ '$type': 'app.bsky.richtext.facet#link', uri: LISTEN_URL }] }]
    end

    def neils_birthday?(date = Date.today)
      date.month == 11 && date.day == 12
    end

    private

    # +text+ cut to at most +length+ graphemes, at a word boundary where
    # possible, with an ellipsis if anything was cut.
    def fit(text, length)
      return text if graphemes(text) <= length
      return '' if length <= ELLIPSIS.length

      cut = text.grapheme_clusters.first(length - ELLIPSIS.length).join
      word_end = cut.rindex(/\s/)
      cut = cut[0, word_end] if word_end&.positive?
      "#{cut.rstrip}#{ELLIPSIS}"
    end

    def graphemes(text)
      text.grapheme_clusters.size
    end

    # Posts in a new thread, to prevent blocking the streaming of data.
    def post(text)
      return if @disabled

      Thread.new do
        session = create_session
        create_post(session, text) if session
      rescue Faraday::Error => e
        RustRadio.logger.error("Bluesky post failed: #{e.message}")
      end
    end

    def create_session
      response = connection.post('com.atproto.server.createSession', identifier: @handle, password: @app_password)
      return response.body if response.success?

      RustRadio.logger.error("Bluesky login failed (#{response.status}): #{error_message(response)}")
      nil
    end

    def create_post(session, text)
      record = { '$type': 'app.bsky.feed.post', text:, facets: link_facets(text), langs: ['en'],
                 createdAt: Time.now.utc.iso8601(3) }
      response = connection.post('com.atproto.repo.createRecord',
                                 { repo: session['did'], collection: 'app.bsky.feed.post', record: },
                                 'Authorization' => "Bearer #{session['accessJwt']}")
      return if response.success?

      RustRadio.logger.error("Bluesky post failed (#{response.status}): #{error_message(response)}")
    end

    def connection
      Faraday.new(url: "#{SERVICE_URL}/xrpc/") do |faraday|
        faraday.request :json
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
      end
    end

    def error_message(response)
      body = response.body
      body.is_a?(Hash) ? [body['error'], body['message']].compact.join(': ') : body.to_s
    end
  end
end
