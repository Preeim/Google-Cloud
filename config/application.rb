require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Izolált In-App Rails Engine-ek betöltése (Sakk és Kaszinó Modulok)
require_relative "../engines/chess/lib/chess"
require_relative "../engines/casino/lib/casino"

module GoogleCloudHub
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    config.time_zone = "UTC"

    # Rack::Attack bekapcsolása spamelés és DoS elleni védelemhez
    config.middleware.use Rack::Attack

  end
end
