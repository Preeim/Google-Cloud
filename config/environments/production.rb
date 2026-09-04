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

  # Nginx fordított proxy kezeli az SSL-t (Let's Encrypt) és a domaineket
  config.hosts.clear

  # Action Cable WebSocket beállítások éles környezetben:
  # Engedélyezzük a bankrepo.hu domainről érkező WebSocket handshake kéréseket
  config.action_cable.disable_request_forgery_protection = true
  config.action_cable.url = "/cable"
  config.action_cable.allowed_request_origins = [
    "https://bankrepo.hu",
    "http://bankrepo.hu",
    "https://www.bankrepo.hu",
    "http://www.bankrepo.hu",
    /https?:\/\/bankrepo\.hu.*/,
    /https?:\/\/127\.0\.0\.1.*/,
    /https?:\/\/localhost.*/
  ]
end
