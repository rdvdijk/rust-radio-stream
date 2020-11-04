require 'sinatra/base'
require 'haml'
require 'sassc'

module RustRadio
  module Web
    class UI < Sinatra::Base
      set :logging, false # doesn't do anything?
      set :views,         File.expand_path("../../../../views", __FILE__)
      set :public_folder, File.expand_path("../../../../public", __FILE__)

      after do
        ActiveRecord::Base.connection.close
      end

      get "/" do
        @playlist = Playlist.where(name: "Default").first
        playlist_show_ids = @playlist.entries.map(&:show_id)

        @shows_not_on_playlist = Show.all.reject do |show|
          playlist_show_ids.include?(show.id)
        end

        haml :index
      end

      get "/stylesheet.css" do
        scss :stylesheet
      end

      get "/favicon.ico" do
      end

      post "/move/:entry_id/to_top" do |entry_id|
        entry = PlaylistEntry.find(entry_id)
        entry.move_to_top
        "ok"
      end

      post "/move/:entry_id/below/:other_entry_id" do |entry_id, other_entry_id|
        entry = PlaylistEntry.find(entry_id)
        other_entry = PlaylistEntry.find(other_entry_id)
        entry.move_below(other_entry)
        "ok"
      end

      post "/remove/:entry_id" do |entry_id|
        entry = PlaylistEntry.find(entry_id)
        entry.destroy
        "ok"
      end

      post "/add/:show_id" do |show_id|
        playlist = Playlist.where(name: "Default").first
        show = Show.find(show_id)

        playlist.entries.create(show: show)
        "ok"
      end
    end
  end
end
