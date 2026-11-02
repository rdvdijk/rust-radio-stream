# frozen_string_literal: true

require 'twitter'

module RustRadio
  # Updates Twitter/X
  class Tweeter
    def initialize(config)
      @twitter = Twitter::REST::Client.new do |twitter_config|
        @disabled = config['disabled']
        twitter_config.consumer_key        = config['consumer_key']
        twitter_config.consumer_secret     = config['consumer_secret']
        twitter_config.access_token        = config['oauth_token']
        twitter_config.access_token_secret = config['oauth_token_secret']
      end
    end

    # Tweet in a new thread, to prevent blocking the streaming of data.
    def tweet(message)
      return if @disabled

      Thread.new do
        @twitter.update(message)
      end
    end

    def show_update(show_info)
      tweet("Now playing: #{show_info}")
    end
  end
end
