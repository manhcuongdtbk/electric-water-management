Rails.application.routes.draw do
  devise_for :users

  # F07: Soát lại quân số
  resource :personnel_review, only: [ :show ]

  resources :monthly_periods, only: [ :create ] do
    member do
      patch :unlock
    end
  end

  resources :contact_points do
    resource :personnel, only: [ :show, :update ], controller: :personnel do
      patch :toggle_review
    end
    resources :meters, except: [ :show ]
  end

  resource :unit_config, only: [ :show, :update ]
  resource :electricity_supply, only: [ :show, :update ]
  resource :meter_readings, only: [ :show, :update ]
  resource :monthly_summary, only: [ :show ] do
    post :recalculate
  end

  # F15: Quản lý tài khoản
  resources :users, only: [ :index, :new, :create, :edit, :update ] do
    member do
      patch :lock
      patch :unlock
    end
  end

  root "contact_points#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
