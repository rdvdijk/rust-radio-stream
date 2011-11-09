require 'shout'

module RustRadio
  class Streamer

    def initialize(config)
      s             = Shout.new
      s.host        = config["hostname"]
      s.port        = config["port"]
      s.password    = config["password"]
      s.format      = Shout::MP3
      s.protocol    = Shout::ICY
      s.description = config["description"]
      s.genre       = config["genre"]
      s.name        = config["name"]
      s.url         = config["url"]
      @shout = s
    end

    def connect
      @shout.connect
    end

    def disconnect
      @shout.disconnect
    end

    def send(data)
      @shout.send data
    end

    def sync
      @shout.sync
    end

    def metadata=(metadata)
      @shout.metadata = metadata
    end

  end
end
