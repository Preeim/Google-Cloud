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

    # Képek és avatarok
    policy.img_src     :self, :data

    # Flash és más objektumok tiltása
    policy.object_src  :none

    # Scriptek
    policy.script_src  :self, :unsafe_inline

    # Stílusok
    policy.style_src   :self, :unsafe_inline

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
