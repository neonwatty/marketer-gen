Rails.application.routes.draw do
  resources :journey_templates do
    member do
      post :clone
      post :use_template
    end
  end
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin' unless Rails.env.test?
  root "home#index"
  
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  
  resource :session
  resources :passwords, param: :token
  
  # User management routes (protected by Pundit policies)
  resources :users, only: [:index, :show]
  
  # Profile management
  resource :profile, only: [:show, :edit, :update]
  
  # Session management
  resources :user_sessions, only: [:index, :destroy]
  
  # Activity tracking
  resources :activities, only: [:index]
  
  # Activity reports
  resource :activity_report, only: [:show] do
    member do
      get :export
    end
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
