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
      puts "[#{@shout.name}] Connecting to #{@shout.host}:#{@shout.port}.."
      @shout.connect
    end

    def disconnect
      puts "[#{@shout.name}] Disconnecting form #{@shout.host}:#{@shout.port}.."
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
