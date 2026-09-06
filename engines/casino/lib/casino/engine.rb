# ==============================================================================
# Bánk's Repository - Kaszinó Modul Engine Definíció (Casino::Engine)
# ==============================================================================
# Izolált Rails Engine (isolate_namespace Casino), amely önálló MVC réteggel,
# saját útválasztással és Action Cable csatornákkal rendelkezik.
# ==============================================================================

module Casino
  class Engine < ::Rails::Engine
    isolate_namespace Casino

    initializer "casino.assets.precompile" do |app|
      # Ide kerülnek az assetek ha szükségesek
    end

    config.after_initialize do
      if defined?(::Rails::Server) || ENV["START_CASINO_SCHEDULER"] == "true"
        require_relative "scheduler"
        Casino::Scheduler.start!
      end
    end
  end
end

