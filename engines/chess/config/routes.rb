# ==============================================================================
# Bánk's Repository - Sakk Modul Belső Útválasztás (Chess::Engine.routes)
# ==============================================================================
# A /chess alatt elérhető privát végpontok definíciója.
# Nem ütközik a Core platform útvonalaival.
# ==============================================================================

Chess::Engine.routes.draw do
  root to: "matches#index"
  resources :matches, only: [:index, :show, :create]
end

