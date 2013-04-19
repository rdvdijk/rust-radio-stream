require 'rubygems'
require 'bundler'

Bundler.setup

$:.unshift(File.join(File.dirname(__FILE__), "lib"))
require 'rust_radio'

# bootstrap DataMapper
config = YAML.load_file("config/config.yml")["config"]
database = config["database"]
username = database["username"]
password = database["password"]
hostname = database["hostname"]
database = database["database"]

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => hostname,
  :username => username,
  :password => password,
  :database => database
)

