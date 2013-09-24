source 'https://rubygems.org'

if ENV['ACTIVE_RECORD'] == "3.2"
  gem 'activerecord', '~> 3.2.0'
else
  gem 'activerecord', '~> 4.0.0'
end

gem 'bundler', '~> 1.3'
gem 'rake'

group :development do
  gem 'pry'
end

group :test do
  gem 'rspec', '>= 2.14'
  gem 'sqlite3'
  gem 'database_cleaner'
end

gemspec
