ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" if File.exist?("Gemfile.lock") # Speed up boot-time, if cached.

# Biztosítjuk a SECRET_KEY_BASE meglétét fejlesztői környezetben (tiszta Ruby, ActiveSupport nélkül)
secret_file = File.expand_path("../.secret_key_base", __dir__)
current_secret = ENV["SECRET_KEY_BASE"].to_s.strip

if current_secret.empty?
  if File.exist?(secret_file)
    file_content = File.read(secret_file).to_s.strip
    current_secret = file_content unless file_content.empty?
  end
  # Fejlesztői/teszt környezetben automatikus véletlenszerű kulcsgenerálás hardcoded string helyett
  if current_secret.empty? && ENV["RAILS_ENV"] != "production"
    require "securerandom"
    current_secret = SecureRandom.hex(64)
    begin
      File.write(secret_file, current_secret)
    rescue StandardError
      # ignore if filesystem read-only
    end
  end
  ENV["SECRET_KEY_BASE"] = current_secret unless current_secret.empty?
end

# JSON quirks_mode kompatibilitás Rails 7.1 számára
begin
  require "json"
  module JSON
    class << self
      if method_defined?(:load) && !method_defined?(:_original_boot_load)
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

      if method_defined?(:parse) && !method_defined?(:_original_boot_parse)
        alias_method :_original_boot_parse, :parse
        def parse(source, opts = {})
          if opts.is_a?(Hash)
            o = opts.dup
            o.delete(:quirks_mode)
            o.delete("quirks_mode")
            _original_boot_parse(source, o)
          else
            _original_boot_parse(source, opts)
          end
        end
      end
    end
  end
rescue StandardError
  # ignore during early boot if json not yet loaded
end

