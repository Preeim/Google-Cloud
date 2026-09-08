# ==============================================================================
# Bánk's Repository - Felhasználó Modell (User)
# ==============================================================================
# A platform központi hitelesítési és jogosultsági entitása.
# Kezeli az RBAC szerepköröket, a fiókzárolási logikát, a párhuzamos munkameneteket
# és az egyes beépülő modulokhoz (pl. Sakk) való hozzáférést.
# ==============================================================================

class User < ApplicationRecord
  has_secure_password

  # Szerepkörök definíciója: normál tag, moderátor, adminisztrátor (Bánk)
  enum :role, {
    user: "user",
    moderator: "moderator",
    admin: "admin"
  }, default: "user"

  # Fiók életciklus státuszok: aktív, felfüggesztett (tiltott), függőben lévő
  enum :status, {
    active: "active",
    suspended: "suspended",
    pending: "pending"
  }, default: "active"

  # Asszociációk
  has_many :active_sessions, dependent: :destroy
  has_many :user_app_permissions, dependent: :destroy
  has_many :app_definitions, through: :user_app_permissions
  has_one :casino_profile, class_name: "Casino::Profile", dependent: :destroy
  has_many :chat_messages, dependent: :destroy

  # Audit napló kapcsolatok
  has_many :audit_logs_as_actor, class_name: "AuditLog", foreign_key: :actor_user_id, dependent: :nullify
  has_many :audit_logs_as_target, class_name: "AuditLog", foreign_key: :target_user_id, dependent: :nullify

  # Jelenlét és profil scope-ok
  scope :online, -> { where("last_seen_at >= ?", 5.minutes.ago) }

  # Hitelesítési adatok normalizálása és tisztítása a validáció előtt
  before_validation :normalize_credentials

  # Szigorú RFC-kompatibilis e-mail formátum (megakadályozza az SQL injection karaktereket, vezérlőjeleket és szóközöket)
  STRICT_EMAIL_REGEX = /\A[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+\z/

  # Validációk
  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 3, maximum: 25 },
                       format: { with: /\A[a-zA-Z0-9_]+\z/, message: "csak betűket, számokat és alulvonást tartalmazhat" }

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    length: { maximum: 254 },
                    format: { with: STRICT_EMAIL_REGEX, message: "érvénytelen formátum" }

  # Jelszó komplexitás: legalább 8 karakter új jelszó megadásakor
  validates :password, length: { minimum: 8 }, if: -> { new_record? || !password.nil? }

  # Profil mezők validációja
  validates :display_name, length: { maximum: 50 }, allow_blank: true
  validates :bio, length: { maximum: 500 }, allow_blank: true
  validates :custom_status, length: { maximum: 120 }, allow_blank: true
  validates :avatar_color, format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/, message: "érvénytelen hexadecimális színkód" }, allow_blank: true

  # ============================================================================
  # Biztonsági és Fiókzárolási Metódusok
  # ============================================================================

  # Ellenőrzi, hogy a fiók jelenleg ideiglenesen le van-e zárva
  def locked?
    locked_until.present? && locked_until > Time.current
  end

  # Fiók zárolása megadott időtartamra (alapértelmezetten 15 perc)
  def lock_access!(duration = 15.minutes)
    update_columns(locked_until: duration.from_now)
  end

  # Zárolás feloldása és hibás kísérlet számláló törlése
  def unlock_access!
    update_columns(failed_logins_count: 0, locked_until: nil)
  end

  # Sikeres bejelentkezés naplózása és számlálók alaphelyzetbe állítása
  def record_successful_login!
    update_columns(
      failed_logins_count: 0,
      locked_until: nil,
      last_login_at: Time.current
    )
  end

  # Hibás bejelentkezési kísérlet regisztrálása; 5 kísérlet után zárolás
  def record_failed_login!
    new_count = failed_logins_count + 1
    if new_count >= 5
      update_columns(failed_logins_count: new_count, locked_until: 15.minutes.from_now)
    else
      update_columns(failed_logins_count: new_count)
    end
  end

  # ============================================================================
  # Modul és Jogosultság Ellenőrzés
  # ============================================================================

  # Eldönti, hogy a felhasználó jogosult-e egy adott app (pl. "chess") megnyitására
  def can_access_app?(app_slug)
    # Az adminisztrátor mindenhez hozzáfér
    return true if admin?

    # Inaktív vagy lezárt fiók semmihez sem fér hozzá
    return false unless active? && !locked?

    app = AppDefinition.find_by(slug: app_slug)
    return false unless app

    # Ha a modul globálisan le van tiltva vagy karbantartás alatt van
    return false if app.state_disabled? || app.state_maintenance?

    # Ha a modul alapértelmezetten minden aktív tag számára elérhető
    return true if app.is_default_accessible?

    # Ellenkező esetben nézzük az egyéni jogosultsági rekordot
    perm = user_app_permissions.find_by(app_definition: app)
    perm.present? && perm.access_level != "none" && (perm.expires_at.nil? || perm.expires_at > Time.current)
  end

  # ============================================================================
  # Profil és Jelenlét (Presence) Segédmetódusok
  # ============================================================================

  # Igaz, ha az utolsó aktivitás 5 percen belül történt
  def online?
    last_seen_at.present? && last_seen_at >= 5.minutes.ago
  end

  # Frissíti az utolsó aktivitás időbélyegét
  def touch_last_seen!
    update_columns(last_seen_at: Time.current)
  end

  # Megjelenítendő név: ha van beállítva display_name, azt adja vissza, egyébként a username-et
  def effective_name
    display_name.presence || username
  end

  # Kezdőbetűk az avatarhoz (pl. "Bánk" -> "BÁ", "John Doe" -> "JD")
  def avatar_initials
    parts = effective_name.strip.split(/\s+/)
    if parts.length >= 2
      (parts[0][0].to_s + parts[1][0].to_s).upcase
    else
      effective_name[0..1].to_s.upcase
    end
  end

  # Biztonságos hex avatar szín
  def custom_avatar_color
    avatar_color.presence || "#38bdf8"
  end

  private

  # Felhasználónév és email cím normalizálása (whitespace és kisbetűsítés)
  def normalize_credentials
    self.username = username.to_s.strip if username.present?
    self.email = email.to_s.strip.downcase if email.present?
  end
end
