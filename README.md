Rust Radio Ruby Runner
======================

This is an all-Ruby replacement of the current ices0 with Perl module version of [Rust Radio](http://www.rustradio.org).

It uses [ruby-shout](https://github.com/niko/ruby-shout) to stream to a [SHOUTcast](http://www.shoutcast.com/) server. It reads FLAC files using [ruby-audio](https://github.com/warhammerkid/ruby-audio) and encodes these files to MP3 using [icanhasaudio](https://github.com/tenderlove/icanhasaudio).

Note that all of these libs have been forked for minor tweaks.

REQUIREMENTS
------------

- liblame-dev
- libsndfile-dev
- libshout-dev
- libflac-dev

