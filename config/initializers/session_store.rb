# ==============================================================================
# Bánk's Repository - Biztonságos Munkamenet (Session) Konfiguráció
# ==============================================================================
# Beállítja a session cookie védelmi szintjeit (HttpOnly, Secure, SameSite),
# megelőzve az XSS alapú cookie-lopást és a CSRF támadásokat.
# ==============================================================================

Rails.application.config.session_store :cookie_store, {
  key: "_banks_repository_session",
  # Csak HTTPS kapcsolaton keresztül küldhető (élesben kötelező)
  secure: Rails.env.production?,
  # JavaScriptből (document.cookie) elérhetetlen
  httponly: true,
  # CSRF védelem: azonos eredetű kérésekhez köti a sütit, külső GET kéréseknél megőrzi
  same_site: :lax,
  # 30 napos lejárati idő a kényelmes, de biztonságos használathoz
  expire_after: 30.days
}

