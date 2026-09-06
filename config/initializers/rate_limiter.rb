# ==============================================================================
# Bánk's Repository - Rate Limiter (Kérés- és Brute-Force Korlátozó)
# ==============================================================================
# Ez a middleware megelőzi a brute-force támadásokat a kritikus végpontokon
# (bejelentkezés, regisztráció), valamint védi az e2-micro VM erőforrásait.
# A Rails.cache / Redis mechanizmusát használja külső gem függőség nélkül,
# így nem okoz verzióütközést a Ruby 3.3.0 parserrel.
# ==============================================================================

module Security
  class RateLimiter
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)

      # 1. Bejelentkezési kísérletek szűrése (POST /login)
      if request.post? && request.path == "/login"
        client_ip = request.ip
        cache_key = "rate_limit:login:#{client_ip}"

        # Jelenlegi kísérletek lekérdezése
        attempts = Rails.cache.read(cache_key).to_i

        # Maximum 5 próbálkozás / IP / 1 perc
        if attempts >= 5
          return rate_limit_response("Túl sok bejelentkezési kísérlet. Kérjük, várj 1 percet a következő próbálkozás előtt!")
        end

        # Számláló növelése és 1 perces lejárati idő beállítása
        Rails.cache.write(cache_key, attempts + 1, expires_in: 1.minute)
      end

      # 2. Regisztrációs kísérletek korlátozása (POST /register)
      if request.post? && request.path == "/register"
        client_ip = request.ip
        cache_key = "rate_limit:register:#{client_ip}"

        attempts = Rails.cache.read(cache_key).to_i

        # Maximum 3 regisztráció / IP / 1 óra
        if attempts >= 3
          return rate_limit_response("Túl sok regisztráció erről az IP címről. Kérjük, próbáld újra később!")
        end

        Rails.cache.write(cache_key, attempts + 1, expires_in: 1.hour)
      end

      @app.call(env)
    end

    private

    def rate_limit_response(message)
      [
        429,
        {
          "Content-Type" => "text/html; charset=utf-8",
          "Retry-After" => "60"
        },
        [
          <<-HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <title>429 - Too Many Requests</title>
            <style>
              body { background: #0a0f1d; color: #f1f5f9; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
              .box { background: #11192e; border: 1px solid #f43f5e; padding: 32px; border-radius: 12px; max-width: 480px; text-align: center; }
              h1 { color: #f43f5e; margin-top: 0; }
              p { color: #94a3b8; font-size: 1.1rem; line-height: 1.6; }
              a { color: #38bdf8; text-decoration: none; font-weight: bold; }
            </style>
          </head>
          <body>
            <div class="box">
              <h1>⚠️ Hozzáférés Korlátozva (429)</h1>
              <p>#{message}</p>
              <p><a href="/">Vissza a főoldalra</a></p>
            </div>
          </body>
          </html>
          HTML
        ]
      ]
    end
  end
end

# Megjegyzés: A kérésszám-korlátozást a dedikált és robusztus Rack::Attack
# (config/initializers/rack_attack.rb) kezeli egységes formázással és JSON/HTML támogatással.
# A felesleges duplikáció elkerülése végett a middleware használata mellőzve.
# Rails.application.config.middleware.use Security::RateLimiter

