require 'shout'

module RustRadio
  RECONNECT_SLEEP = 1.0

  class Streamer
    def initialize(general, mount)
      @shout = Shout::Connection.new do |conn|
        conn.configuration.host = mount["hostname"]
        conn.configuration.port = mount["port"]
        conn.configuration.mount = mount["mount"] if mount["mount"]
        conn.configuration.user = mount["username"]
        conn.configuration.password = mount["password"]
        conn.configuration.protocol = mount["protocol"].to_sym
        conn.configuration.format = mount["format"].intern

        # Audio information
        conn.configuration.audio_info.bitrate = mount["bitrate"]
        #conn.configuration.audio_info.samplerate = 44100
        #conn.configuration.audio_info.channels = 2

        # Stream metadata
        conn.configuration.meta.name = general["name"]
        conn.configuration.meta.genre = general["genre"]
        conn.configuration.meta.description = general["description"]
        conn.configuration.meta.url = general["url"]
      end
      @send_metadata = mount["send_metadata"]
    end

    # Connect to the server, and try to reconnect if connecting fails.
    def connect
      begin
        log "Connecting."
        @shout.connect
        log "Connected."
      rescue Shout::SocketError, Shout::ConnectionError => error
        log "Error connecting: #{error}"
        log "Sleeping for #{RECONNECT_SLEEP}s."
        sleep RECONNECT_SLEEP
        log "Reconnecting."
        retry
      rescue Shout::ShoutError => error
        log "Error connecting: #{error}"
        raise error
      end
    end

    def disconnect
      log "Disconnecting."
      @shout.disconnect if @shout.connected?
    end

    # Send data, and try to reconnect if something goes wrong.
    def send(data)
      begin
        @shout.send(data)
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
      puts "[#{@shout.configuration.name}@#{@shout.configuration.host}:#{@shout.configuration.port}#{@shout.configuration.mount}] #{message}"
    end
  end
end
