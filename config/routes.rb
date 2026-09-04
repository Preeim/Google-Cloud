Rails.application.routes.draw do
  # General Testing Console & App Frame
  root "test#index"

  # Authentication routes
  get  "/login",    to: "sessions#new",         as: :login
  post "/login",    to: "sessions#create"
  delete "/logout", to: "sessions#destroy",      as: :logout
  get  "/logout",   to: "sessions#destroy" # Convenient link for GET

  get  "/register", to: "registrations#new",    as: :register
  post "/register", to: "registrations#create"

  # WebSocket Action Cable mount
  mount ActionCable.server => "/cable"
end

