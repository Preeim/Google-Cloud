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

    layout "chess/application"
  end
end
