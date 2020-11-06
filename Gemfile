source "https://rubygems.org"
gem "ruby-shout"
gem "ruby-audio"
gem "icanhasaudio", "0.1.3", git: "git@github.com:rdvdijk/icanhasaudio.git" # needed because of invalid gemspec
gem "flacinfo-rb"
gem "json"

gem 'activerecord'
#gem 'activesupport'
gem 'pg'
gem 'acts_as_list', require: false

gem "thor"

gem "puma"
gem "sinatra"
gem "haml"
gem "sassc"

gem "twitter"
gem "fb_graph2"

group :staging, :production do
  gem "rack-ssl-enforcer"
end

group :development do
  gem "pry-nav"
  gem "capistrano", "~> 3.14", require: false
end
