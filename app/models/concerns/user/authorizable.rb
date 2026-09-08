# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - User::Authorizable Concern
# ==============================================================================
# Kezeli a felhasználó modul- és alkalmazáshozzáférési jogosultságait.
# ==============================================================================

module User::Authorizable
  extend ActiveSupport::Concern

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
