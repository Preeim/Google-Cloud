# ==============================================================================
# Bánk's Repository - Content Security Policy (CSP) Konfiguráció
# ==============================================================================
# Ez a fájl határozza meg a böngészők által betölthető erőforrások (scriptek,
# stílusok, képek, WebSocket kapcsolatok) biztonsági szabályait.
# ==============================================================================

Rails.application.configure do
  config.content_security_policy do |policy|
    # Alapértelmezés: saját forrás
    policy.default_src :self

    # Betűtípusok és ikonok
    policy.font_src    :self, :data

    # Képek és avatarok (plusz chessboard.js bábuk CDN)
    policy.img_src     :self, :data, "https://chessboardjs.com"

    # Flash és más objektumok tiltása
    policy.object_src  :none

    # Scriptek (plusz külső könyvtárak a sakk modulhoz)
    policy.script_src  :self, :unsafe_inline, "https://cdnjs.cloudflare.com", "https://code.jquery.com", "https://unpkg.com"

    # Stílusok (plusz külső könyvtárak a sakk modulhoz)
    policy.style_src   :self, :unsafe_inline, "https://unpkg.com"

    # Hálózati kapcsolatok: Fetch, XHR és Action Cable WebSocket csatornák
    # Teljes körűen engedélyezi a ws:// és wss:// kapcsolatokat a domainhez
    policy.connect_src :self, :blob,
                       "wss://bankrepo.hu", "ws://bankrepo.hu",
                       "wss://www.bankrepo.hu", "ws://www.bankrepo.hu",
                       "wss:", "ws:",
                       "https://bankrepo.hu", "http://bankrepo.hu",
                       "ws://localhost:3000", "ws://127.0.0.1:3000"

    # Clickjacking védelem
    policy.frame_ancestors :self

    # Űrlap célállomás
    policy.form_action :self

    # Alap URI
    policy.base_uri :self
  end
end
