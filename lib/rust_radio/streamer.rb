require 'shout'

module RustRadio
  RECONNECT_SLEEP = 1.0

  class Streamer
    def initialize(general, mount)
      s             = Shout.new

      # general
      s.description = general["description"]
      s.genre       = general["genre"]
      s.name        = general["name"]
      s.url         = general["url"]

      # mount
      s.host        = mount["hostname"]
      s.port        = mount["port"]
      s.username    = mount["username"]
      s.password    = mount["password"]
      s.protocol    = Shout.const_get(mount["protocol"])
      s.format      = Shout.const_get(mount["format"])
      s.bitrate     = mount["bitrate"].to_s
      s.mount       = mount["mount"] if mount["mount"]

      @shout = s
      @send_metadata = mount["send_metadata"]
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
      if @send_metadata
        @metadata = metadata
        resend_metadata
      end
    end

    private

    def resend_metadata
      @shout.metadata = @metadata
    end

    def log(message)
      puts "[#{@shout.name}@#{@shout.host}:#{@shout.port}#{@shout.mount}] #{message}"
    end
  end
end
