# frozen_string_literal: true

require 'date'
require 'faraday'
require 'time'
require 'rust_radio/bluesky_text'

module RustRadio
  # Posts to Bluesky every time a new show starts. Logs in with an app
  # password for every post: there are only a few posts a day, which keeps
  # far below the login rate limit and needs no token refreshing.
  class BlueskyPoster
    SERVICE_URL = 'https://bsky.social'
    LISTEN_URL = 'https://rustradio.org'
    BIRTHDAY_GREETING = 'Happy birthday, Neil!'
    SEPARATOR = "\n\n"

    def initialize(config)
      @disabled = config['disabled']
      @handle = config['handle']
      @app_password = config['app_password']
    end

    def show_update(show)
      post(texts_for(show))
    end

    # Returns the posting thread, or nil when disabled.
    def announce(text)
      post(announcement_texts(text))
    end

    def announcement_texts(text)
      BlueskyText.thread('', text.strip)
    end

    def disabled?
      @disabled
    end

    # The notes come last, so the title and the link are always in the post.
    def texts_for(show)
      head = head_for(show)
      notes = show.notes.to_s.strip
      notes.empty? ? [head] : BlueskyText.thread("#{head}#{SEPARATOR}", notes)
    end

    def head_for(show)
      [
        (BIRTHDAY_GREETING if neils_birthday?),
        "Now playing: #{show.long_title}",
        "Listen now on #{LISTEN_URL}"
      ].compact.join(SEPARATOR)
    end

    def neils_birthday?(date = Date.today)
      date.month == 11 && date.day == 12
    end

    private

    # Posts in a new thread, to prevent blocking the streaming of data. The
    # thread's value is whether all posts worked.
    def post(texts)
      return if @disabled

      Thread.new do
        session = create_session
        session ? post_thread(session, texts) : false
      rescue Faraday::Error => e
        RustRadio.logger.error("Bluesky post failed: #{e.message}")
        false
      end
    end

    # Each reply answers the one before it, so they read as a thread. A
    # failed post stops the rest, which would otherwise reply to nothing.
    def post_thread(session, texts)
      root = parent = nil
      texts.all? do |text|
        parent = create_post(session, text, reply: root && { root:, parent: })
        root ||= parent
      end
    end

    def create_session
      response = connection.post('com.atproto.server.createSession', identifier: @handle, password: @app_password)
      return response.body if response.success?

      RustRadio.logger.error("Bluesky login failed (#{response.status}): #{error_message(response)}")
      nil
    end

    # Returns the post's { uri:, cid: }, which a reply refers to, or nil if
    # posting failed.
    def create_post(session, text, reply: nil)
      response = connection.post('com.atproto.repo.createRecord',
                                 { repo: session['did'], collection: 'app.bsky.feed.post',
                                   record: record(text, reply) },
                                 authorization(session))
      return response.body.slice('uri', 'cid').transform_keys(&:to_sym) if response.success?

      RustRadio.logger.error("Bluesky post failed (#{response.status}): #{error_message(response)}")
      nil
    end

    def record(text, reply)
      { '$type': 'app.bsky.feed.post', text:, facets: BlueskyText.link_facets(text), reply:, langs: ['en'],
        createdAt: Time.now.utc.iso8601(3) }.compact
    end

    def authorization(session)
      { 'Authorization' => "Bearer #{session['accessJwt']}" }
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
