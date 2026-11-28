# frozen_string_literal: true

module RustRadio
  # Text for Bluesky posts: split into a thread of posts that fit, with
  # links marked so Bluesky shows them as links.
  module BlueskyText
    # Bluesky's limit, counted in graphemes: what a reader sees as one
    # character, so an emoji with modifiers counts once.
    MAX_LENGTH = 300
    ELLIPSIS = '…'
    # Punctuation right after a URL usually ends the sentence, not the URL.
    URL = %r{https?://\S*[^\s.,;:!?'")…]}

    module_function

    # A post with +prefix+ and as much of +text+ as fits, and replies with
    # the rest.
    def thread(prefix, text)
      first, rest = split_to_fit(text, MAX_LENGTH - prefix.grapheme_clusters.size)
      texts = ["#{prefix}#{first}".rstrip]
      until rest.empty?
        reply, rest = split_to_fit(rest, MAX_LENGTH - ELLIPSIS.length)
        texts << "#{ELLIPSIS}#{reply}"
      end
      texts
    end

    # Bluesky doesn't turn URLs in the text into links: a facet marks each
    # link, by its UTF-8 byte offsets, not character offsets.
    def link_facets(text)
      text.to_enum(:scan, URL).map do
        start, finish = Regexp.last_match.byteoffset(0)
        { index: { byteStart: start, byteEnd: finish },
          features: [{ '$type': 'app.bsky.richtext.facet#link', uri: Regexp.last_match(0) }] }
      end
    end

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
  end
end
