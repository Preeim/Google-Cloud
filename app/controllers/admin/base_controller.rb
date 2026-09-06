# ==============================================================================
# Bánk's Repository - Adminisztrátori Bázis Vezérlő (Admin::BaseController)
# ==============================================================================
# Minden adminisztrátori vezérlő ebből az osztályból származik.
# Garantálja, hogy kizárólag érvényes, admin szerepkörű felhasználók érhetik el,
# és beállítja a dedikált adminisztrációs felületi sablont (layout: 'admin').
# ==============================================================================

module Admin
  class BaseController < ApplicationController
    before_action :require_admin!
    layout "admin"
  end
end

