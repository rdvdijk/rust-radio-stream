#!/bin/bash
source /etc/profile.d/chruby.sh
chruby 3.4.12
./bin/rustradio web
