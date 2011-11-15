require 'twitter'

module RustRadio
  class Tweeter
    def initialize(config)
      Twitter.configure do |twitter_config|
        @disabled = config["disabled"]
        twitter_config.consumer_key       = config["consumer_key"]
        twitter_config.consumer_secret    = config["consumer_secret"]
        twitter_config.oauth_token        = config["oauth_token"]
        twitter_config.oauth_token_secret = config["oauth_token_secret"]
      end
    end

    # Tweet in a new thread, to prevent blocking the streaming of data.
    def tweet(message)
      Thread.new do
        Twitter.update(message)
      end unless @disabled
    end

    def show_update(show_info)
      tweet("Now playing: #{show_info}")
    end
  end
end
