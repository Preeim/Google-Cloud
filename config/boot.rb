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

# JSON quirks_mode kompatibilitás Rails 7.1 számára
begin
  require "json"
  module JSON
    class << self
      if method_defined?(:load)
        alias_method :_original_boot_load, :load
        def load(source, proc = nil, options = {})
          if options.is_a?(Hash)
            opts = options.dup
            opts.delete(:quirks_mode)
            opts.delete("quirks_mode")
            _original_boot_load(source, proc, opts)
          else
            _original_boot_load(source, proc, options)
          end
        end
      end
    end
  end
rescue StandardError
  # ignore during early boot if json not yet loaded
end

