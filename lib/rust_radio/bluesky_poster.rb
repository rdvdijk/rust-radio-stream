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
      post(texts_for(show))
    end

    # The post, and replies with the rest of the notes if they don't fit.
    # The notes come last, so the title and the link are always in the post.
    def texts_for(show)
      head = head_for(show)
      notes, rest = split_to_fit(show.notes.to_s.strip, MAX_LENGTH - (head + SEPARATOR).grapheme_clusters.size)
      texts = [notes.empty? ? head : "#{head}#{SEPARATOR}#{notes}"]
      until rest.empty?
        reply, rest = split_to_fit(rest, MAX_LENGTH - ELLIPSIS.length)
        texts << "#{ELLIPSIS}#{reply}"
      end
      texts
    end

    def head_for(show)
      [
        (BIRTHDAY_GREETING if neils_birthday?),
        "Now playing: #{show.long_title}",
        "Listen now on #{LISTEN_URL}"
      ].compact.join(SEPARATOR)
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

    # Splits +text+ into a part of at most +length+ graphemes and the rest.
    # The cut is at a word boundary where possible, and a cut part ends in
    # an ellipsis. With no room for any text, the part is empty.
    def split_to_fit(text, length)
      return [text, ''] if text.grapheme_clusters.size <= length
      return ['', text] if length <= ELLIPSIS.length

      cut = text.grapheme_clusters.first(length - ELLIPSIS.length).join
      word_end = cut.rindex(/\s/)
      cut = cut[0, word_end] if word_end&.positive?
      ["#{cut.rstrip}#{ELLIPSIS}", text[cut.length..].lstrip]
    end

    # Posts in a new thread, to prevent blocking the streaming of data.
    def post(texts)
      return if @disabled

      Thread.new do
        session = create_session
        post_thread(session, texts) if session
      rescue Faraday::Error => e
        RustRadio.logger.error("Bluesky post failed: #{e.message}")
      end
    end

    # Each reply answers the one before it, so they read as a thread. A
    # failed post stops the rest, which would otherwise reply to nothing.
    def post_thread(session, texts)
      root = parent = nil
      texts.each do |text|
        parent = create_post(session, text, reply: root && { root:, parent: })
        break unless parent

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
      { '$type': 'app.bsky.feed.post', text:, facets: link_facets(text), reply:, langs: ['en'],
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
