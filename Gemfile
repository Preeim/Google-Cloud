source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby ">= 3.2.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.4"

# Use MySQL as the database for Active Record
gem "mysql2", "~> 0.5"

# Use the Puma web server
gem "puma", ">= 5.0"

# Use Active Model has_secure_password for user authentication
gem "bcrypt", "~> 3.1.7"

# Use stable connection_pool compatible with Ruby 3.3.0
gem "connection_pool", "~> 2.4.1"

# Use Redis for Action Cable pubsub in production
gem "redis", "~> 5.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use JavaScript import maps by default
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  # Speed up commands on slow systems
  gem "web-console"
end

