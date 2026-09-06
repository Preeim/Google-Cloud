# ==============================================================================
# Bánk's Repository - Rajzvászon Belső Útválasztó (Canvas::Engine.routes)
# ==============================================================================

Canvas::Engine.routes.draw do
  root to: "boards#show"

  resource :board, only: [:show] do
    post :clear
    post :toggle_freeze
    post :save_snapshot
  end
end

