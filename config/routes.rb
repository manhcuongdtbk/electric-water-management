Rails.application.routes.draw do
  devise_for :users

  devise_scope :user do
    post "sessions/extend", to: "sessions#extend_session", as: :extend_session
  end

  # F16: Force password change on first login
  resource :password_change, only: [ :edit, :update ]

  # F07: Soát lại quân số
  resource :personnel_review, only: [ :show ]

  resources :monthly_periods, only: [ :index, :create, :edit, :update ] do
    member do
      patch :unlock
    end
  end

  resources :rank_quotas, only: [ :index, :edit, :update ]

  resources :pump_stations, except: [ :show ] do
    resources :meters, only: [ :new, :create, :edit, :update, :destroy ],
              controller: "pump_station_meters"
    resources :assignments, only: [ :new, :create, :edit, :update, :destroy ],
              controller: "pump_station_assignments"
  end
  resource :pump_station_readings, only: [ :show, :update ]

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

  resources :organizations, only: [ :index, :new, :create, :edit, :update, :destroy ]

  resources :main_meters, except: [ :show ]

  resources :backups, only: [ :index, :create ] do
    collection do
      post :restore
      delete :destroy_file
    end
  end

  resources :audit_logs, only: [ :index ]

  resource :dashboard, only: [ :show ], controller: "dashboard"
  resource :history, only: [ :show ], controller: "history"
  root "dashboard#show"

  get "up" => "rails/health#show", as: :rails_health_check
end
