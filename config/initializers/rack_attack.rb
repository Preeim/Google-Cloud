# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - Rack::Attack Biztonsági és Kérésszám-korlátozó Konfiguráció
# ==============================================================================
# Védelmet nyújt:
# - Brute-force bejelentkezések ellen (IP és felhasználónév alapú fojtás)
# - Tömeges bot-regisztrációk ellen
# - Kaszinó fogadási végpontok spamelése / DoS ellen
# - Általános HTTP túlterhelés / agresszív web-scrapperek ellen
# ==============================================================================

class Rack::Attack
  # Ha a Rails.cache nem elérhető vagy nem konfigurált, használjunk belső memóriatárolót
  Rack::Attack.cache.store = Rails.cache || ActiveSupport::Cache::MemoryStore.new

  # ----------------------------------------------------------------------------
  # 1. Fehérlista (Safelist): Helyi hurok / belső szerver forgalom felmentése
  # ----------------------------------------------------------------------------
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # ----------------------------------------------------------------------------
  # 2. Bejelentkezési kísérletek korlátozása (Brute-Force és hitelesítési spam védelem)
  # ----------------------------------------------------------------------------
  # Max 10 kísérlet percenként egyetlen IP címről
  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/login" && req.post?
  end

  # Max 5 kísérlet percenként adott felhasználónévre (elosztott botnet elleni védelem)
  throttle("logins/username", limit: 5, period: 1.minute) do |req|
    if req.path == "/login" && req.post?
      (req.params["login"] || req.params["username"]).to_s.downcase.strip.presence
    end
  end

  # ----------------------------------------------------------------------------
  # 3. Új fiók regisztráció korlátozása (Fiók-farmok és botok elleni védelem)
  # ----------------------------------------------------------------------------
  # Max 5 regisztrációs kísérlet 5 percenként egy IP címről
  throttle("registrations/ip", limit: 5, period: 5.minutes) do |req|
    req.ip if req.path == "/register" && req.post?
  end

  # ----------------------------------------------------------------------------
  # 4. Kaszinó Fogadási & Játék Végpontok Védelme (Kattintgató script és spam védelem)
  # ----------------------------------------------------------------------------
  # Max 40 tétrakási kérés percenként IP-nként
  throttle("casino/bets/ip", limit: 40, period: 1.minute) do |req|
    if req.post? && req.path.match?(%r{\A/casino/tables/[^/]+/bet\z})
      req.ip
    end
  end

  # Max 40 játékos akció (Hit/Stand/Double) percenként IP-nként
  throttle("casino/actions/ip", limit: 40, period: 1.minute) do |req|
    if req.post? && req.path.match?(%r{\A/casino/tables/[^/]+/action\z})
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # 4/B. Globális Chat Üzenetküldés Védelme (Spam és flood védelem)
  # ----------------------------------------------------------------------------
  # Max 30 üzenetküldési kérés percenként IP-nként a REST végponton
  throttle("chat/messages/ip", limit: 30, period: 1.minute) do |req|
    if req.post? && req.path == "/chat_messages"
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # 5. Általános Kérésszám-korlátozás (Globális DoS és Scraper Védelem)
  # ----------------------------------------------------------------------------
  # Max 300 kérés percenként IP-nként (statikus assetek kivételével)
  throttle("req/ip", limit: 300, period: 1.minute) do |req|
    unless req.path.start_with?("/assets", "/cable")
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # 6. Korlátozási Válasz (429 Too Many Requests válaszformázás)
  # ----------------------------------------------------------------------------
  self.throttled_responder = lambda do |req|
    now = Time.now.to_i
    match_data = req.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period] ? (match_data[:period] - (now % match_data[:period])) : 60

    headers = {
      "Content-Type" => req.env["HTTP_ACCEPT"]&.include?("application/json") ? "application/json" : "text/html; charset=utf-8",
      "Retry-After"  => retry_after.to_s,
      "Content-Security-Policy" => "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; frame-ancestors 'self'",
      "X-Frame-Options" => "SAMEORIGIN",
      "X-Content-Type-Options" => "nosniff",
      "Referrer-Policy" => "strict-origin-when-cross-origin"
    }

    if req.env["HTTP_ACCEPT"]&.include?("application/json")
      body = {
        success: false,
        error: "Túl sok kérés érkezett ebből a forrásból. Kérjük várj #{retry_after} másodpercet az újbóli próbálkozás előtt.",
        retry_after: retry_after
      }.to_json
    else
      body = <<~HTML
        <!DOCTYPE html>
        <html lang="hu">
        <head>
          <meta charset="utf-8">
          <title>429 Túl Sok Kérés - Bánk's Repository</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0b0f19; color: #e2e8f0; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
            .box { max-width: 480px; width: 100%; background: #151d30; border: 1px solid #2a3854; border-radius: 12px; padding: 32px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
            h1 { color: #f59e0b; margin-top: 0; font-size: 1.6rem; }
            p { color: #94a3b8; font-size: 0.95rem; line-height: 1.6; }
            .timer { font-size: 1.1rem; font-weight: bold; color: #38bdf8; margin: 20px 0; }
            a { color: #38bdf8; text-decoration: none; font-weight: 600; }
          </style>
        </head>
        <body>
          <div class="box">
            <h1>🛡️ Kérésszám-korlát Túllépve</h1>
            <p>Rendszerünk védelme érdekében a túl gyakori vagy automatizált kéréseket átmenetileg várakoztatjuk.</p>
            <div class="timer">Újrapróbálkozás lehetséges: #{retry_after} másodperc múlva</div>
            <p><a href="/">Vissza a kezdőlapra</a></p>
          </div>
        </body>
        </html>
      HTML
    end

    [429, headers, [body]]
  end
end
