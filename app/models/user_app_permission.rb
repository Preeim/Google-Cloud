# ==============================================================================
# Bánk's Repository - Felhasználói App Jogosultság (UserAppPermission)
# ==============================================================================
# Granuláris hozzáférés-vezérlési kapcsolat a felhasználó és a modul között.
# Támogatja a különböző hozzáférési szinteket (alapértelmezett, béta-tesztelő,
# modul-menedzser), valamint a határozott idejű jogosultságokat.
# ==============================================================================

class UserAppPermission < ApplicationRecord
  belongs_to :user
  belongs_to :app_definition
  belongs_to :granted_by, class_name: "User", foreign_key: :granted_by_user_id, optional: true

  # Jogosultsági szintek
  enum access_level: {
    none: "none",
    standard: "standard",
    beta_tester: "beta_tester",
    manager: "manager"
  }, _default: "standard"

  validates :user_id, uniqueness: { scope: :app_definition_id, message: "már rendelkezik jogosultsággal ehhez a modulhoz" }
  validates :access_level, presence: true
  validates :granted_at, presence: true

  # Ellenőrzi, hogy a jogosultság még érvényes-e
  def active?
    access_level != "none" && (expires_at.nil? || expires_at > Time.current)
  end
end

