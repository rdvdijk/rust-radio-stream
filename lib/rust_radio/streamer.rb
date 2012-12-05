require 'shout'

module RustRadio
  RECONNECT_SLEEP = 1.0

  class Streamer
    def initialize(config)
      s             = Shout.new
      s.host        = config["hostname"]
      s.port        = config["port"]
      s.mount       = config["mount"] if config["mount"]
      s.password    = config["password"]
      s.format      = Shout.const_get(config["format"])
      s.protocol    = Shout.const_get(config["protocol"])
      s.description = config["description"]
      s.genre       = config["genre"]
      s.name        = config["name"]
      s.url         = config["url"]
      s.bitrate     = config["bitrate"].to_s
      @shout = s
    end

    # Connect to the server, and try to reconnect if connecting fails.
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

    # Send data, and try to reconnect if something goes wrong.
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

    # Sync, which waits an appropriate time until the next data can be sent.
    def sync
      @shout.sync
    end

    # Time to wait in milliseconds
    def delay
      @shout.delay
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
