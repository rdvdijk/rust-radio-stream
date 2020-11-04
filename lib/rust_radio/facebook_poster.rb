require "fb_graph2"

module RustRadio
  class FacebookPoster

    def initialize(config)
      @disabled = config["disabled"]
      @page = FbGraph2::User.me(config["access_token"])
    end

    def post(message)
      Thread.new do
        @page.feed!(message: message)
      end unless @disabled
    end

    def show_update(show_info)
      post("Now playing: #{show_info}")
    end

  end
end
