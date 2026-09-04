# ==============================================================================
# Bánk's Repository - Content Security Policy (CSP) Konfiguráció
# ==============================================================================
# Ez a fájl határozza meg a böngészők által betölthető erőforrások (scriptek,
# stílusok, képek, WebSocket kapcsolatok) biztonsági szabályait.
# Segít megelőzni az XSS (Cross-Site Scripting) és adatbefecskendezéses támadásokat.
# ==============================================================================

Rails.application.configure do
  config.content_security_policy do |policy|
    # Alapértelmezés: csak a saját domainről tölthető be bármilyen erőforrás
    policy.default_src :self

    # Betűtípusok: saját forrás és standard webes betűk
    policy.font_src    :self, :data

    # Képek: saját képek, SVG data URI-k, és avatarok/ikonok
    policy.img_src     :self, :data

    # Objektumok: beágyazott Flash/Java appletek teljes tiltása
    policy.object_src  :none

    # Scriptek: saját domain és importmap scriptek engedélyezése
    policy.script_src  :self

    # Stílusok: saját stíluslapok és inline stílusok a dinamikus UI elemekhez
    policy.style_src   :self, :unsafe_inline

    # Hálózati kapcsolatok: Fetch, XHR és Action Cable WebSocket csatorna
    # Támogatja a helyi fejlesztést (ws://) és az éles bankrepo.hu wss:// kapcsolatokat
    if Rails.env.development?
      policy.connect_src :self, "ws://localhost:3000", "ws://127.0.0.1:3000"
    else
      policy.connect_src :self, "wss://bankrepo.hu", "https://bankrepo.hu"
    end

    # Beágyazás megelőzése: csak saját domained ágyazhatja be az oldalt (Clickjacking védelem)
    policy.frame_ancestors :self

    # Űrlapok célállomása: kizárólag a saját domainre küldhetnek POST kérést
    policy.form_action :self

    # Alap URI védelem
    policy.base_uri :self
  end

  # Nonce generálás a dinamikusan injektált scriptekhez (szükség esetén)
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)
end

