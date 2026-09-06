# ==============================================================================
# Bánk's Repository - Aktív Munkamenet Modell (ActiveSession)
# ==============================================================================
# Kezeli az érvényes bejelentkezéseket. A böngészőben tárolt nyers session
# tokent SHA-256 lenyomatként őrzi meg, így adatbázis-szivárgás esetén sem
# használható fel a token a felhasználó nevében.
# ==============================================================================

class ActiveSession < ApplicationRecord
  belongs_to :user

  validates :session_token_digest, presence: true, uniqueness: true
  validates :last_activity_at, presence: true
  validates :expires_at, presence: true

  # Kiszűri a már lejárt munkameneteket
  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Új munkamenet inicializálása biztonságos kriptográfiai tokennel
  def self.create_from_request!(user, request, expire_duration = 30.days)
    raw_token = SecureRandom.hex(32)
    digest = Digest::SHA256.hexdigest(raw_token)

    session_record = create!(
      user: user,
      session_token_digest: digest,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      last_activity_at: Time.current,
      expires_at: expire_duration.from_now
    )

    # Visszatér a nyers tokennel (amit cookie-ban tárolunk) és a rekorddal
    [raw_token, session_record]
  end

  # Keresés a nyers token lenyomata alapján
  def self.find_by_raw_token(raw_token)
    return nil if raw_token.blank?
    digest = Digest::SHA256.hexdigest(raw_token)
    active.find_by(session_token_digest: digest)
  end

  # Frissíti az utolsó aktivitást és kitolja a lejárati időt
  def touch_activity!(sliding_duration = 30.days)
    update_columns(
      last_activity_at: Time.current,
      expires_at: sliding_duration.from_now
    )
  end

  # Ellenőrzi, hogy a munkamenet lejárt-e
  def expired?
    expires_at <= Time.current
  end
end

