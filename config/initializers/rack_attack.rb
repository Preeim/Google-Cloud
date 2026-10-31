# frozen_string_literal: true

class Rack::Attack
  Rack::Attack.cache.store = Rails.cache || ActiveSupport::Cache::MemoryStore.new

  # 1. Fehérlista: Localhost / belső kérések felmentése
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # 2. Általános kérésszám-korlátozás (DDoS / agresszív scraper védelem)
  # Max 300 kérés percenként egy IP címről
  throttle("req/ip", limit: 300, period: 1.minute) do |req|
    req.ip
  end
end
