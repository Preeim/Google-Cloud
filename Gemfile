source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby ">= 3.2.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.4"

# Use MySQL as the database for Active Record
gem "mysql2", "~> 0.5"

# Use the Puma web server
gem "puma", ">= 5.0"

# Stability pins for Ruby 3.3.0 environment
gem "connection_pool", "~> 2.4.1"
gem "json", "< 2.8.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  gem "web-console"
end
