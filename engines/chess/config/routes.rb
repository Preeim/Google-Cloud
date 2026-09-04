# ==============================================================================
# Bánk's Repository - Sakk Modul Belső Útválasztás (Chess::Engine.routes)
# ==============================================================================
# A /chess alatt elérhető privát végpontok definíciója.
# Nem ütközik a Core platform útvonalaival.
# ==============================================================================

Chess::Engine.routes.draw do
  # Sakk lobby és kezdőoldal (/chess)
  root to: "dashboard#index"

  # Jövőbeli végpontok vázlata:
  # resources :games, only: [:index, :show, :create]
  # resources :lobbies, only: [:index, :create, :join]
end

