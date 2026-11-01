# frozen_string_literal: true
source 'https://rubygems.org'
gem 'ffi-shout', '0.1.0'
gem 'flacinfo-rb', '1.0' # 1.1.0 has debugging output
gem 'json'
gem 'lame'
gem 'ruby-audio'

gem 'activerecord'
# gem 'activesupport'
gem 'acts_as_list', require: false
gem 'pg'

gem 'thor'

gem 'haml'
gem 'puma'
gem 'sassc'
gem 'sinatra'

gem 'fb_graph2'
gem 'twitter'

gem 'faraday'
gem 'nokogiri'
gem 'rrd-ffi'

group :staging, :production do
  gem 'rack-ssl-enforcer'
end

group :development do
  gem 'capistrano', '~> 3.14', require: false
  gem 'pry-nav'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
end
