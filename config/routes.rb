Rails.application.routes.draw do
  get "shared/:token", to: "shared_campaign_plans#show", as: :shared_campaign_plan
  resources :brand_identities do
    member do
      patch :activate
      patch :deactivate  
      post :process_materials
    end
  end
  
  resources :campaign_plans do
    member do
      post :generate
      post :regenerate
      patch :archive
      get :export_pdf
      get :export_presentation
      post :share_plan
      post :refresh_analytics
      get :analytics_report
      post :sync_external_analytics
      post :start_execution
      post :complete_execution
    end
    
    # Nested content management
    resources :generated_contents, except: [:index, :show, :edit, :update, :destroy] do
      collection do
        post :generate
      end
    end
  end
  
  # Content management (can be accessed independently)
  resources :generated_contents do
    member do
      post :regenerate
      patch :approve
      patch :publish
      patch :archive
      post :create_variants
    end
    
    collection do
      get :search
    end
  end
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  root "home#index"
  
  resource :profile, only: [:show, :edit, :update]
  
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  
  resource :session
  resources :passwords, param: :token
  
  resources :journeys do
    collection do
      get :compare
    end
    member do
      patch :reorder_steps
      get :suggestions
      post :duplicate
      patch :archive
    end
    resources :journey_steps, except: [:show]
  end

  # API routes
  namespace :api do
    namespace :v1 do
      scope :content_generation do
        post :social_media, to: 'content_generation#social_media'
        post :email, to: 'content_generation#email'
        post :ad_copy, to: 'content_generation#ad_copy'
        post :landing_page, to: 'content_generation#landing_page'
        post :campaign_plan, to: 'content_generation#campaign_plan'
        post :variations, to: 'content_generation#variations'
        post :optimize, to: 'content_generation#optimize'
        post :brand_compliance, to: 'content_generation#brand_compliance'
        post :analytics_insights, to: 'content_generation#analytics_insights'
        get :health, to: 'content_generation#health'
      end
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
