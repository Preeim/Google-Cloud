# ==============================================================================
# Bánk's Repository - Biztonságos Munkamenet (Session) Konfiguráció
# ==============================================================================
# Beállítja a session cookie védelmi szintjeit (HttpOnly, Secure, SameSite),
# megelőzve az XSS alapú cookie-lopást és a CSRF támadásokat.
#
# Fontos: Ruby 3.0+ alatt a konfigurációs kulcsokat kötelező kulcsszavas
# argumentumként (kwargs, kapcsos zárójelek NÉLKÜL) átadni!
# ==============================================================================

Rails.application.config.session_store :cookie_store,
  key: "_banks_repository_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
  expire_after: 30.days
