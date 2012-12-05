Rust Radio Ruby Runner
======================

This is an all-Ruby replacement of the previous ices0 with Perl module 
version of [Rust Radio](http://www.rustradio.org).

It uses [ruby-shout](https://github.com/niko/ruby-shout) to stream to 
a [SHOUTcast](http://www.shoutcast.com/) server and [Icecast](http://icecast.org/) server.

It reads FLAC files and encodes to Vorbis using [ruby-audio](https://github.com/warhammerkid/ruby-audio)
and encodes to MP3 using [icanhasaudio](https://github.com/tenderlove/icanhasaudio).

Note that some of these libs have been forked for minor tweaks.

REQUIREMENTS
------------

- libmp3lame-dev
- libsndfile1-dev
- libshout3-dev

