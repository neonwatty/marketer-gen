Rails.application.routes.draw do
  get "shared/:token", to: "shared_campaign_plans#show", as: :shared_campaign_plan
  resources :brand_identities do
    member do
      patch :activate
      patch :deactivate  
      post :process_materials
    end
    
    # Brand adaptation routes
    resources :brand_adaptations, path: 'adaptations' do
      member do
        post :activate
        post :deactivate
        post :archive
        post :test
        post :duplicate
        patch :update_effectiveness
      end
      
      collection do
        post :adapt_content
        post :analyze_consistency
        get :analyze_compatibility
      end
    end
  end
  
  resources :campaign_plans do
    member do
      get :generate
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
    
    # Campaign Intelligence routes
    resources :campaign_intelligence, path: 'intelligence', controller: 'campaign_intelligence' do
      collection do
        post :generate
        post :regenerate
        get :analytics
        get :export
      end
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
  
  # Platform integrations for external advertising platforms
  resources :platform_integrations, param: :platform do
    member do
      post :test_connection
      post :sync_data
    end
    
    collection do
      post :sync_all
      get :export
      get 'sync_status/:job_id', to: 'platform_integrations#sync_status', as: :sync_status
    end
  end
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  root "home#index"
  
  # Interactive demo tours
  resources :demos, only: [:index] do
    collection do
      get :start_tour
      post :track_completion
    end
  end

  # Help and documentation
  get "help", to: "pages#help", as: :help_page
  
  resource :profile, only: [:show, :edit, :update]
  
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  
  resource :session
  resources :passwords, param: :token
  
  resources :journeys do
    collection do
      get :compare
      get :select_template
      post :create_from_template
      get :template_preview
      patch :bulk_archive
      patch :bulk_duplicate
      patch :bulk_delete
    end
    member do
      patch :reorder_steps
      get :suggestions
      post :duplicate
      patch :archive
    end
    resources :journey_steps, except: [:show]
  end

  # Webhook routes - must be placed before API routes for proper routing
  scope :webhooks do
    # Platform-specific webhook endpoints
    post 'meta', to: 'webhooks#meta_webhook'
    post 'facebook', to: 'webhooks#facebook_webhook'
    post 'instagram', to: 'webhooks#instagram_webhook'
    post 'linkedin', to: 'webhooks#linkedin_webhook'
    post 'google_ads', to: 'webhooks#google_ads_webhook'
    post ':platform', to: 'webhooks#generic_webhook', constraints: { platform: /[a-z_]+/ }
    
    # Webhook verification endpoints (for platform setup)
    get ':platform/verify', to: 'webhooks#verify', constraints: { platform: /[a-z_]+/ }
    post ':platform/verify', to: 'webhooks#verify', constraints: { platform: /[a-z_]+/ }
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
      
      # Validation endpoints
      scope :validations do
        post :validate_field, to: 'validations#validate_field'
        post 'users/email_address', to: 'validations#users_email_address'
        post 'campaign_plans/name', to: 'validations#campaign_plans_name'
        post 'journeys/name', to: 'validations#journeys_name'
      end
      
      # Progress tracking endpoints
      scope :progress do
        get 'campaign_plans/:id', to: 'progress#campaign_plan_progress', as: :campaign_plan_progress
        get 'tasks/:task_id', to: 'progress#task_progress', as: :task_progress
      end
      
      # Smart suggestions endpoints
      scope :suggestions do
        get 'campaign_plans', to: 'suggestions#campaign_plan_suggestions'
        get 'journeys', to: 'suggestions#journey_suggestions'
        get 'onboarding', to: 'suggestions#onboarding_status'
        get 'onboarding_progress', to: 'suggestions#onboarding_progress'
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
