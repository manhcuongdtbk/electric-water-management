Rails.application.routes.draw do
  devise_for :users

  resources :contact_points do
    resource :personnel, only: [ :show, :update ], controller: :personnel
    resources :meters, except: [ :show ]
  end

  root "contact_points#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
