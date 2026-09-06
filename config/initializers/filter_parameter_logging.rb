# ==============================================================================
# Bánk's Repository - Érzékeny Paraméterek Naplózási Szűrése
# ==============================================================================
# Ez a fájl konfigurálja, hogy milyen paramétereket kell kitakarni a naplófájlokban
# (log/production.log, log/development.log), megelőzve a jelszavak és titkos
# tokenek véletlenszerű kiszivárgását a szervernaplókból.
# ==============================================================================

Rails.application.config.filter_parameters += [
  :passw,
  :password,
  :password_confirmation,
  :password_digest,
  :secret,
  :token,
  :_key,
  :crypt,
  :salt,
  :certificate,
  :otp,
  :ssn,
  :session_token,
  :session_token_digest
]

