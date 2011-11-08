#!/usr/bin/env ruby
require 'rubygems'
require 'bundler'

Bundler.setup
require 'ruby-audio'
require 'shout'
require 'icanhasaudio'
require 'yaml'
require 'flacinfo'

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

class Encoder

  def initialize(config)
    writer = Audio::MPEG::Encoder.new
    writer.vbr_type = Audio::MPEG::Encoder::VBR_OFF
    writer.bitrate = config["bitrate"]
    writer.init
    @encoder = writer
  end

  def encode(in_buffer, &block)
    @encoder.encode_io(in_buffer, &block)
  end

  def flush(&block)
    @encoder.flush_io(&block)
  end

end

class RubyAudioStreamer < Streamer

  def initialize
    config = YAML.load_file("config.yml")["config"]

    # Shout streamer
    @streamer = Streamer.new(config)
    @streamer.connect

    # MP3 encoder
    @encoder = Encoder.new(config)
  end

  # Stream a FLAC file
  def stream(file)
    begin
      update_metadata(file)
      RubyAudio::Sound.open(file) do |snd|
        while buf = snd.read(:short, 64*1024) and buf.real_size > 0
          samples = buffer_to_samples(buf)
          stream_mp3(samples)
        end
      end
    ensure
      @streamer.disconnect
    end
  end

  # Convert the RubyAudio Buffer to an array of samples.
  def buffer_to_samples(buffer)
    samples = []
    buffer.each do |left, right|
      samples << left << right
    end

    samples
  end

  # Convert the given samples to MP3 data and stream it.
  def stream_mp3(samples)
    in_buffer = StringIO.new
    in_buffer.write(samples.pack("v*"))
    in_buffer.seek(0)

    @encoder.encode(in_buffer) do |data|
      shout(data)
    end
  end

  # Stream the given MP3 data to the ShoutCast server.
  def shout(mp3_data)
    @streamer.send mp3_data
    @streamer.sync # sleep a while
  end

  # Set metadata
  def update_metadata(file)
    flac = FlacInfo.new(file)
    title  = flac.tags["TITLE"]
    album = flac.tags["ALBUM"]

    metadata = ShoutMetadata.new
    metadata.add "song", "#{title} - (#{album})"
    @streamer.metadata = metadata
  end

end

radio = RubyAudioStreamer.new
radio.stream("ny1974-05-16d1t01.flac")
# radio.stream("whitenoise60.flac")

