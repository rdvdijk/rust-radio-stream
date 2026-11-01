# frozen_string_literal: true

module RustRadio
  # Updates TuneIn status
  class TuneIn
    def initialize(config)
      @disabled = config['disabled']
      @station_id = config['station_id']
      @partner_id = config['partner_id']
      @partner_key = config['partner_key']
    end

    # Update in a new thread, to prevent blocking the streaming of data.
    def tune_in(title, artist, album)
      return if @disabled

      Thread.new do
        conn = Faraday.new(url: 'http://air.radiotime.com') do |faraday|
          faraday.adapter Faraday.default_adapter
        end
        conn.get '/Playing.ashx',
                 {
                   id: @station_id,
                   partnerId: @partner_id,
                   partnerKey: @partner_key,
                   title: title,
                   artist: artist,
                   album: album
                 }
      end
    end

    def song_update(song)
      info = song.info
      tune_in(info[:title], info[:artist], info[:album])
    end
  end
end
