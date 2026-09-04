require "active_support/core_ext/integer/time"

# ==============================================================================
# Bánk's Repository - Éles Környezeti Konfiguráció (Production)
# ==============================================================================
Rails.application.configure do
  # Kód újratöltés tiltása élesben a maximális teljesítmény érdekében
  config.enable_reloading = false

  # Eager loading: minden osztály betöltése a memóriába induláskor
  config.eager_load = true

  # Részletes hibaüzenetek elrejtése a látogatók elől
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Statikus fájlok kiszolgálásának engedélyezése (Nginx mögött)
  config.public_file_server.enabled = true

  # Naplózási szint és kérés-azonosító címkézés
  config.log_level = :info
  config.log_tags = [ :request_id ]

  # Nyelvi tartalékok
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  # HTTPS Kényszerítés és HSTS (Let's Encrypt tanúsítvánnyal védve)
  config.force_ssl = true
  config.ssl_options = {
    hsts: { subdomains: true, preload: true, expires: 2.years },
    redirect: { exclude: ->(request) { request.path == "/health" } }
  }

  # Nginx fordított proxy kezeli a domaineket; belső blokkolás feloldása
  config.hosts.clear
end
