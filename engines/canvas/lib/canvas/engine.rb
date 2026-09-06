# ==============================================================================
# Bánk's Repository - Rajzvászon Modul Engine Definíció (Canvas::Engine)
# ==============================================================================
# Izolált Rails Engine (isolate_namespace Canvas), amely önálló MVC réteggel,
# saját útválasztással és csatornákkal rendelkezik.
# ==============================================================================

module Canvas
  class Engine < ::Rails::Engine
    isolate_namespace Canvas

    initializer "canvas.assets.precompile" do |app|
      # Canvas-specifikus asset előkészítés
    end
  end
end

