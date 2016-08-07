#!/bin/bash
source /etc/profile.d/chruby.sh
chruby 2.3.1
./bin/rustradio web
