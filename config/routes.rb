Rails.application.routes.draw do
  get "campaigns/index"
  get "test/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Journey Templates Management
  resources :journey_templates, only: [:index, :show] do
    member do
      get :preview
      post :apply_to_campaign
      post :duplicate
      patch :publish
      patch :unpublish
    end
    collection do
      get :categories
      get :search
    end
  end

  # Journeys Management with Validation and Persistence
  resources :journeys do
    member do
      post :validate
      post :duplicate
      get :versions
      post :restore_version
      get :export
      post :import
      post :auto_save
    end
  end

  # Campaigns Management with Journey Builder
  resources :campaigns do
    resource :customer_journey, only: [:show, :create, :update, :destroy] do
      member do
        get :builder
      end
    end
    
    # Nested journeys under campaigns
    resources :journeys, except: [:index]
  end

  # Content Management with Rich Text Editor
  resources :content_management do
    collection do
      post :preview
    end
    member do
      get :export
    end
  end

  # Brand Assets Management
  resources :brand_assets, except: [ :show ] do
    collection do
      post :upload_multiple
    end
    member do
      patch :update_metadata
      delete :destroy
    end
  end

  # Content Generation API
  namespace :api do
    namespace :v1 do
      namespace :generate do
        post :social_media
        post :ad_copy
        post :email
        post :landing_page
        post :campaign_plan
        post :brand_analysis
      end
    end
  end

  # AI Services API
  resources :ai_services, only: [] do
    collection do
      get :status
      get :rate_limit_status
      get :cache_statistics
      post :documentation_lookup
      post :batch_documentation_lookup
      post :suggest_libraries
      delete :clear_cache
      delete :clear_ai_cache
    end
  end

  # AI Monitoring Dashboard
  resources :ai_monitoring, only: [:index] do
    collection do
      get :metrics
      get :costs
      get :performance
      get :alerts
      get :health_check
      get :export
      get :stream
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "brand_assets#index"
end
