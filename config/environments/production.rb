require "active_support/core_ext/integer/time"
require "active_support/core_ext/object/blank"

# ==============================================================================
# Bánk's Repository - Éles Környezeti Konfiguráció (Production)
# ==============================================================================
Rails.application.configure do
  # Kód újratöltés tiltása élesben a maximális teljesítmény érdekében
  config.enable_reloading = false

  # Eager loading: minden osztály betöltése a memóriába induláskor
  config.eager_load = true

  # Titkosítási kulcs (secret_key_base) éles környezetben
  secret_file_val = File.exist?(Rails.root.join(".secret_key_base")) ? File.read(Rails.root.join(".secret_key_base")).to_s.strip : nil
  effective_secret = (ENV["SECRET_KEY_BASE"].to_s.strip unless ENV["SECRET_KEY_BASE"].to_s.strip.empty?) ||
                     (secret_file_val unless secret_file_val.to_s.empty?)
  if effective_secret.blank?
    raise "KRITIKUS BIZTONSÁGI HIBA: A SECRET_KEY_BASE környezeti változó nincs konfigurálva éles környezetben!"
  end
  config.secret_key_base = effective_secret

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

  # Szigorú Host Authorization (DNS Rebinding védelem)
  config.hosts = [
    "bankrepo.hu",
    "www.bankrepo.hu",
    "127.0.0.1",
    "localhost",
    /\A.*\.bankrepo\.hu\z/
  ]

  # Szigorú SSL/TLS és HSTS kényszerítés (Strict-Transport-Security)
  config.force_ssl = true
  config.ssl_options = {
    hsts: { subdomains: true, preload: true, expires: 2.years },
    redirect: { exclude: ->(request) { request.path.start_with?("/up") } }
  }

  # Szigorú HTTP biztonsági fejlécek (HSTS, Anti-Clickjacking, Sniffing és Jogosultság védelem)
  config.action_dispatch.default_headers = {
    "X-Frame-Options" => "SAMEORIGIN",
    "X-XSS-Protection" => "0",
    "X-Content-Type-Options" => "nosniff",
    "X-Permitted-Cross-Domain-Policies" => "none",
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), payment=()",
    "Strict-Transport-Security" => "max-age=63072000; includeSubDomains; preload",
    "Content-Security-Policy" => "default-src 'self'; font-src 'self' data:; img-src 'self' data: https://chessboardjs.com; object-src 'none'; script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://code.jquery.com https://unpkg.com https://cdn.skypack.dev https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://unpkg.com; connect-src 'self' blob: wss://bankrepo.hu ws://bankrepo.hu wss://www.bankrepo.hu ws://www.bankrepo.hu https://bankrepo.hu http://bankrepo.hu ws://localhost:3000 ws://127.0.0.1:3000; frame-ancestors 'self'; form-action 'self'; base-uri 'self';"
  }

  # Action Cable WebSocket beállítások éles környezetben:
  # Engedélyezzük a szigorú Origin védelmet (CSWSH megelőzése) szigorúan horgonyzott regexekkel
  config.action_cable.disable_request_forgery_protection = false
  config.action_cable.url = "/cable"
  config.action_cable.allowed_request_origins = [
    /\Ahttps?:\/\/(www\.)?bankrepo\.hu(:\d+)?\z/,
    /\Ahttps?:\/\/127\.0\.0\.1(:\d+)?\z/,
    /\Ahttps?:\/\/localhost(:\d+)?\z/
  ]
end
