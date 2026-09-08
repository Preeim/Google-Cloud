# ==============================================================================
# Bánk's Repository - Sakk Modul Belső Útválasztás (Chess::Engine.routes)
# ==============================================================================
# A /chess alatt elérhető privát végpontok definíciója.
# Nem ütközik a Core platform útvonalaival.
# ==============================================================================

Chess::Engine.routes.draw do
  root to: "matches#index"
  resources :matches, only: [:index, :show, :create, :destroy] do
    member do
      post :join
      post :cancel
    end
  end

  # Modulhoz kötött Sakk Adminisztráció
  namespace :admin do
    root to: "dashboard#index"
    resource :settings, only: [:show, :edit, :update]
    resources :matches, only: [:index, :show, :destroy] do
      member do
        post :abort
      end
      collection do
        post :cleanup_pending
      end
    end
  end
end

