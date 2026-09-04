# ==============================================================================
# Bánk's Repository - Sakk Modul Bázis Vezérlő (Chess::ApplicationController)
# ==============================================================================
# Minden sakk vezérlő alapja. Örököl a platform központi ApplicationControlleréből,
# így rendelkezik a teljes biztonsági és session kontextussal.
# Minden kérésnél ellenőrzi a felhasználó jogosultságát a sakk modulhoz.
# ==============================================================================

module Chess
  class ApplicationController < ::ApplicationController
    # Kötelező belépés és app jogosultság ellenőrzése
    before_action :authenticate_user!
    before_action -> { check_app_access!("chess") }

    layout "chess/application"
  end
end

