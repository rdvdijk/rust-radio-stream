require 'rubygems'
require 'bundler'
require 'data_mapper'
require 'dm-is-list'

Bundler.setup

$:.unshift(File.join(File.dirname(__FILE__), "lib"))
require 'rust_radio'

# bootstrap DataMapper
config = YAML.load_file("config.yml")["config"]
database = config["database"]
username = database["username"]
password = database["password"]
host = database["host"]
database = database["database"]

uri = "postgres://#{[username,password].compact.join(':')}@#{host}/#{database}"
DataMapper.setup(:default, uri)
DataMapper.finalize

#DataMapper.auto_upgrade!
#DataMapper.auto_migrate!

