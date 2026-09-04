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
  enum role: {
    user: "user",
    moderator: "moderator",
    admin: "admin"
  }, _default: "user"

  # Fiók életciklus státuszok: aktív, felfüggesztett (tiltott), függőben lévő
  enum status: {
    active: "active",
    suspended: "suspended",
    pending: "pending"
  }, _default: "active"

  # Asszociációk
  has_many :active_sessions, dependent: :destroy
  has_many :user_app_permissions, dependent: :destroy
  has_many :app_definitions, through: :user_app_permissions

  # Audit napló kapcsolatok
  has_many :audit_logs_as_actor, class_name: "AuditLog", foreign_key: :actor_user_id, dependent: :nullify
  has_many :audit_logs_as_target, class_name: "AuditLog", foreign_key: :target_user_id, dependent: :nullify

  # Validációk
  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 3, maximum: 25 },
                       format: { with: /\A[a-zA-Z0-9_]+\z/, message: "csak betűket, számokat és alulvonást tartalmazhat" }

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "érvénytelen formátum" }

  # Jelszó komplexitás: legalább 8 karakter új jelszó megadásakor
  validates :password, length: { minimum: 8 }, if: -> { new_record? || !password.nil? }

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
end
