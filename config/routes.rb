# ==============================================================================
# Bánk's Repository - Központi Útválasztó (config/routes.rb)
# ==============================================================================
# Összekapcsolja a Core platform funkcióit, a védett Adminisztrációs felületet,
# az autentikációs végpontokat, a WebSocket szervert és az izolált Rails Engine-eket.
# ==============================================================================

Rails.application.routes.draw do
  # 1. Központi Műszerfal & Kezdőlap
  root "dashboard#index"

  # 2. Fejlesztői & Diagnosztikai Teszt Konzol (megőrizve a /test alatt)
  get "/test", to: "test#index", as: :test_console

  # 3. Hitelesítési Útvonalak (Sessions & Registrations)
  get    "/login",    to: "sessions#new",         as: :login
  post   "/login",    to: "sessions#create"
  delete "/logout",   to: "sessions#destroy",      as: :logout
  get    "/logout",   to: "sessions#destroy"      # Kényelmi GET link navigációhoz

  get    "/register", to: "registrations#new",    as: :register
  post   "/register", to: "registrations#create"

  # 4. Védett Rendszergazdai Névtér (/bank-admin)
  namespace :admin, path: "bank-admin" do
    root to: "dashboard#index"

    resources :users, only: [:index, :edit, :update, :destroy] do
      post :unlock, on: :member
    end

    resources :apps, only: [:index, :edit, :update] do
      post :toggle, on: :member
    end
    resources :audit_logs, only: [:index]
  end

  # 5. Izolált Moduláris Webalkalmazások (Rails Engines)
  mount Chess::Engine => "/chess", as: :chess_app

  # 6. WebSocket Action Cable Végpont
  mount ActionCable.server => "/cable"
end
