# frozen_string_literal: true

require 'shout'

module RustRadio
  RECONNECT_SLEEP = 1.0

  # Connects to an Icecast server, streams audio to it, and updates metadata
  class Streamer
    def initialize(general, mount)
      @shout = Shout::Connection.new do |conn|
        configure_connection(conn.configuration, mount)
        configure_format(conn.configuration, mount)
        configure_meta(conn.configuration.meta, general)
      end
      @send_metadata = mount['send_metadata']
    end

    # Connect to the server, and try to reconnect if connecting fails.
    def connect
      log 'Connecting.'
      @shout.connect
      @chunks_since_connect = 0
      log 'Connected.'
    rescue Shout::SocketIOError, Shout::ConnectionError => e
      log "Error connecting: #{e}"
      log "Sleeping for #{RECONNECT_SLEEP}s."
      sleep RECONNECT_SLEEP
      log 'Reconnecting.'
      retry
    rescue Shout::ShoutError => e
      log "Error connecting: #{e}"
      raise e
    end

    def disconnect
      log 'Disconnecting.'
      @shout.disconnect if @shout.connected?
    end

    # Send data, and try to reconnect if something goes wrong.
    def send(data)
      @shout.send_data(data)
      @chunks_since_connect += 1
      send_pending_metadata
    rescue Shout::ShoutError => e
      log "Error sending data: #{e}"
      disconnect # shout doesn't know it has already been disconnected.. (?)
      connect
      @metadata_pending = true
      retry
    end

    # Sync, which waits an appropriate time until the next data can be sent.
    def sync
      @shout.sync
    end

    # Time to wait in milliseconds
    def delay
      @shout.delay
    end

    # Metadata is sent after audio data, not right away: Icecast silently
    # drops (while reporting success) metadata for an Ogg mount until it has
    # parsed the stream's first pages and knows the codec. It parses them
    # asynchronously, so right after a connect we wait for a second chunk.
    def metadata=(metadata)
      return unless @send_metadata

      @metadata = metadata
      @metadata_pending = true
    end

    private

    def send_pending_metadata
      return unless @metadata_pending && @metadata
      return if @chunks_since_connect < 2

      @shout.metadata = @metadata
      @metadata_pending = false
    end

    def configure_connection(config, mount)
      config.host = mount['hostname']
      config.port = mount['port']
      config.mount = mount['mount'] if mount['mount']
      config.user = mount['username']
      config.password = mount['password']
    end

    def configure_format(config, mount)
      config.protocol = mount['protocol'].to_sym
      config.format = mount['format'].intern
      config.audio_info.bitrate = mount['bitrate']
    end

    def configure_meta(meta, general)
      meta.name = general['name']
      meta.genre = general['genre']
      meta.description = general['description']
      meta.url = general['url']
    end

    def log(message)
      RustRadio.logger.info("[#{log_prefix}] #{message}")
    end

    def log_prefix
      config = @shout.configuration
      "#{config.name}@#{config.host}:#{config.port}#{config.mount}"
    end
  end
end
