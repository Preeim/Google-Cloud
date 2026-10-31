# frozen_string_literal: true

Rails.application.routes.draw do
  root "pages#home"

  # Health check endpoint for uptime monitors
  get "/up", to: proc { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
end
