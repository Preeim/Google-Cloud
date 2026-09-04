# ==============================================================================
# Bánk's Repository - Alkalmazás Definíció Modell (AppDefinition)
# ==============================================================================
# A platformhoz kapcsolt önálló modulok (pl. Sakk, Jegyzetek) központi leírója.
# Lehetővé teszi az adminisztrátornak, hogy karbantartási módba tegyen vagy
# korlátozzon egy-egy mini-appot anélkül, hogy a teljes webhelyet leállítaná.
# ==============================================================================

class AppDefinition < ApplicationRecord
  # Állapotok: aktív, karbantartás alatt, inaktív (tiltva), csak adminisztrátoroknak
  enum :state, {
    active: "active",
    maintenance: "maintenance",
    disabled: "disabled",
    admin_only: "admin_only"
  }, prefix: :state, default: "active"

  # Asszociációk
  has_many :user_app_permissions, dependent: :destroy
  has_many :users, through: :user_app_permissions

  # Validációk
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-_]+\z/ }
  validates :name, presence: true
  validates :mount_path, presence: true

  # Scopes a gyors szűréshez
  scope :available_to_users, -> { where(state: "active") }
  scope :in_maintenance, -> { where(state: "maintenance") }
  scope :guest_accessible, -> { where(requires_login: false) }
  scope :members_only, -> { where(requires_login: true) }

  # Vendégként látogatható-e az alkalmazás
  def guest_accessible?
    !requires_login?
  end

  # Vizuális állapotjelvény segédmetódus
  def badge_color_class
    case state
    when "active" then "badge-success"
    when "maintenance" then "badge-warning"
    when "admin_only" then "badge-admin"
    else "badge-disabled"
    end
  end
end

