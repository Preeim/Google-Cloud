ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" if File.exist?("Gemfile.lock") # Speed up boot-time, if cached.

# Biztosítjuk a SECRET_KEY_BASE meglétét minden környezetben (tiszta Ruby, ActiveSupport nélkül)
secret_file = File.expand_path("../.secret_key_base", __dir__)
current_secret = ENV["SECRET_KEY_BASE"].to_s.strip

if current_secret.empty?
  if File.exist?(secret_file)
    file_content = File.read(secret_file).to_s.strip
    current_secret = file_content unless file_content.empty?
  end
  current_secret = "a4b2c8e1f0d3e5a7b9c6d4e2f1a0b8c7d5e3f2a1b9c0d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7" if current_secret.empty?
  ENV["SECRET_KEY_BASE"] = current_secret
end

