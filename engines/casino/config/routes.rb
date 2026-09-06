# ==============================================================================
# Bánk's Repository - Kaszinó Modul Belső Útválasztás (Casino::Engine.routes)
# ==============================================================================

Casino::Engine.routes.draw do
  root to: "lobby#index"

  resources :tables, only: [:show] do
    member do
      post :bet
      post :spin
      post :action
    end
  end

  resources :leaderboards, only: [:index]

  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [:index, :edit, :update] do
      post :reset, on: :member
    end
    resources :tables, only: [:index] do
      member do
        post :toggle
        post :reset_round
      end
    end
  end
end

