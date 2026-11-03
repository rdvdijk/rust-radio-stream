Rust Radio Ruby Runner
======================

This is an all-Ruby replacement of the previous ices0 with Perl module 
version of [Rust Radio](http://www.rustradio.org).

It uses [ffi-shout](https://github.com/rdvdijk/ffi-shout) to stream to a
[Icecast](http://icecast.org/) server.

It reads FLAC files and encodes to Vorbis using [ffi-sndfile](https://github.com/rdvdijk/ffi-sndfile)
and encodes to MP3 using [lame](https://github.com/rdvdijk/lame).

USAGE
-----

Add a show to the database:

```sh
$ bundle exec bin/rustradio add_show /path/to/liveshow.flac16
```

Start the stream:

```
$ bundle exec bin/rustradio play
```

Start the web console:

```
$ bundle exec bin/rustradio web
```

The web console can also be started using puma:

```
$ bundle exec puma
```

REQUIREMENTS
------------

- `libmp3lame-dev`
- `libsndfile1-dev`
- `libshout3-dev`

Deployment
----------

Use SSH agent for deployments:

```
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa
```
