# ==============================================================================
# Bánk's Repository - Sakk Modul Bázis Vezérlő (Chess::ApplicationController)
# ==============================================================================
# Minden sakk vezérlő alapja. Örököl a platform központi ApplicationControlleréből.
# A jogosultság-ellenőrzés a platform AppDefinition konfigurációjához igazodik:
# - Ha a modul nem igényel bejelentkezést, vendégek is játszhatnak.
# - Ha bejelentkezést igényel, elegánsan átirányít a belépési oldalra.
# ==============================================================================

module Chess
  class ApplicationController < ::ApplicationController
    # Modul hozzáférési szűrő futtatása
    before_action -> { check_app_access!("chess") }
    
    # Vendég azonosító kiosztása, ha nincs belépve felhasználó
    before_action :set_guest_id

    layout "chess/application"

    private

    def set_guest_id
      return if logged_in?
      session[:guest_id] ||= SecureRandom.hex(8)
    end
  end
end
