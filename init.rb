require 'rubygems'
require 'bundler'
require 'data_mapper'

Bundler.setup

$:.unshift(File.join(File.dirname(__FILE__), "lib"))
require 'rust_radio'

# bootstrap DataMapper
DataMapper.setup(:default, 'postgres://rust_radio@localhost/rust_radio')
DataMapper.auto_upgrade!

