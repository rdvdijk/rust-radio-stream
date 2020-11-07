#!/bin/bash
source /etc/profile.d/chruby.sh
chruby 2.7.1
./bin/rustradio rrd
