Rails.application.routes.draw do
  devise_for :users, skip: [:registrations, :passwords, :confirmations, :unlocks]

  root to: "dashboard#show"

  get "up" => "rails/health#show", as: :rails_health_check

  resource :password_change, only: [:edit, :update]

  # XEM KẾT QUẢ
  resource :dashboard, only: [:show], controller: "dashboard"
  resource :billing, only: [:show], controller: "billing" do
    post :recalculate
  end
  resource :history, only: [:show], controller: "history"

  # NHẬP LIỆU
  resource :electricity_supply, only: [:show, :update], controller: "electricity_supply"
  resource :meter_entries, only: [:show, :update], controller: "meter_entries"
  resource :pump_entries, only: [:show, :update], controller: "pump_entries"

  # KHAI BÁO
  resources :contact_points
  resources :blocks
  resources :groups
  resource :unit_config, only: [:show, :update], controller: "unit_config"

  # THIẾT LẬP
  resources :zones do
    member { patch :reassign_manager }
  end
  resources :units
  resources :pump_allocations
  resource :pricing, only: [:show, :update], controller: "pricing" do
    post :open_period
    post :close_period
    post :reopen_period
  end
  resources :ranks

  # HỆ THỐNG
  resources :users
  resources :audit_logs, only: [:index]
  resources :backups, only: [:index]
end
