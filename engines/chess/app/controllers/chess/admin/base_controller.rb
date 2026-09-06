# ==============================================================================
# Bánk's Repository - Sakk Modul Adminisztrációs Bázis Vezérlő
# ==============================================================================

module Chess
  module Admin
    class BaseController < Chess::ApplicationController
      before_action :require_admin!
      layout "chess/admin"
    end
  end
end
