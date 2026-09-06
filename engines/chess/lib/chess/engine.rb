# ==============================================================================
# Bánk's Repository - Sakk Modul Engine Definíció (Chess::Engine)
# ==============================================================================
# Izolált Rails Engine (isolate_namespace Chess), amely önálló MVC réteggel,
# saját útválasztással és csatornákkal rendelkezik anélkül, hogy a Core
# kódterületét szennyezné.
# ==============================================================================

module Chess
  class Engine < ::Rails::Engine
    isolate_namespace Chess

    # Engine belső útvonalak és kódok automatikus betöltése
    initializer "chess.assets.precompile" do |app|
      # Ide kerülnek a sakk-specifikus asset inicializálások
    end
  end
end

