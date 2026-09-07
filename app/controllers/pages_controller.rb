# ==============================================================================
# Bánk's Repository - Statikus és Jogi Oldalak Vezérlője (PagesController)
# ==============================================================================
# Kezeli a nem kereskedelmi hobbi/portfólió projekt jogi dokumentumait:
# - Feltételek & Felelősségkizárás (Terms & Disclaimer)
# - Egyszerűsített Adatkezelési Tájékoztató (Privacy Policy)
# - Impresszum és Kapcsolat (About & Contact)
# ==============================================================================

class PagesController < ApplicationController
  def terms
    @page_title = "Feltételek & Felelősségkizárás"
  end

  def privacy
    @page_title = "Adatkezelési Tájékoztató"
  end

  def about
    @page_title = "Impresszum & Kapcsolat"
  end
end

