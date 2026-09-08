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

  # Concerns
  include User::Lockable
  include User::Authorizable
  include User::Presentable


  private

  # Felhasználónév és email cím normalizálása (whitespace és kisbetűsítés)
  def normalize_credentials
    self.username = username.to_s.strip if username.present?
    self.email = email.to_s.strip.downcase if email.present?
  end
end
