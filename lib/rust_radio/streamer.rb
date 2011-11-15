require 'shout'

module RustRadio
  RECONNECT_SLEEP = 1.0

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
      s.bitrate     = config["bitrate"].to_s
      @shout = s
    end

    def connect
      begin
        log "Connecting."
        @shout.connect
        log "Connected."
      rescue ShoutError => error
        log "Error connecting: #{error}"
        case error.message
        when /^#{ShoutError::SOCKET}/, /^#{ShoutError::NOCONNECT}/
          log "Sleeping for #{RECONNECT_SLEEP}s."
          sleep RECONNECT_SLEEP
          log "Reconnecting."
          retry
        else
          raise error
        end
      end
    end

    def disconnect
      log "Disconnecting."
      @shout.disconnect
    end

    def send(data)
      begin
        @shout.send data
      rescue ShoutError => error
        log "Error sending data: #{error}"
        disconnect # shout doesn't know it has already been disconnected.. (?)
        connect
        resend_metadata
        retry
      end
    end

    def sync
      @shout.sync
    end

    def metadata=(metadata)
      @metadata = metadata
      resend_metadata
    end

    private

    def resend_metadata
      @shout.metadata = @metadata
    end

    def log(message)
      puts "[#{@shout.name}@#{@shout.host}:#{@shout.port}] #{message}"
    end
  end
end
