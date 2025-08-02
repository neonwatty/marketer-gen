Rails.application.routes.draw do
  # Content Management System
  resources :content_repositories, path: 'content' do
    member do
      get :preview
      post :duplicate
      post :publish
      post :archive
      get :analytics
      get :collaboration
      post :regenerate
    end
    
    resources :content_versions, path: 'versions' do
      member do
        get :diff
        post :revert
        get :preview
        post :approve
        post :reject
      end
    end
    
    resources :content_approvals, path: 'approvals', only: [:index, :show, :create, :update]
    resources :content_tags, path: 'tags', only: [:index, :create, :destroy]
  end
  
  # Content Management API
  namespace :api do
    namespace :v1 do
      resources :content_repositories, path: 'content' do
        member do
          get :search
          post :bulk_operations
          get :version_history
          post :auto_save
        end
        
        resources :content_versions, path: 'versions' do
          member do
            get :visual_diff
            post :create_branch
            post :merge
          end
        end
      end
    end
  end

  # Brand management
  resources :brands do
    resources :brand_assets do
      member do
        post :reprocess
        get :download
        get :status
      end
      collection do
        get :batch_status
      end
    end
    resources :brand_guidelines
    resource :messaging_framework do
      member do
        patch :update_key_messages
        patch :update_value_propositions
        patch :update_terminology
        patch :update_approved_phrases
        patch :update_banned_words
        patch :update_tone_attributes
        post :validate_content
        get :export
        post :import
        post :ai_suggestions
        patch :reorder_key_messages
        patch :reorder_value_propositions
        post :add_key_message
        delete :remove_key_message
        post :add_value_proposition
        delete :remove_value_proposition
        get :search_approved_phrases
      end
    end
    resources :brand_analyses, only: [:index, :show, :create] do
      member do
        post :regenerate
      end
    end
    member do
      get :compliance_check
      post :check_content_compliance
    end
  end
  # API endpoints
  namespace :api do
    namespace :v1 do
      # Brand Compliance API
      resources :brands, only: [] do
        namespace :compliance do
          post :check
          post :validate_aspect
          post :preview_fix
          post :validate_and_fix
          get :history
        end
      end
      
      # Journey Management API
      resources :journeys do
        member do
          post :duplicate
          post :publish
          post :archive
          get :analytics
          get :execution_status
        end
        
        # Journey Steps API
        resources :steps, controller: :journey_steps do
          member do
            patch :reorder
            post :duplicate
            post :execute
            get :transitions
            post :transitions, action: :create_transition
            get :analytics
          end
        end
        
        # A/B Tests API
        resources :ab_tests do
          member do
            post :start
            post :stop
            post :declare_winner
            get :results
          end
        end
      end
      
      # Templates API
      resources :templates, controller: :journey_templates do
        member do
          post :instantiate
          post :clone
          post :rate
        end
        
        collection do
          get :categories
          get :industries
          get :popular
          get :recommended
        end
      end
      
      # Analytics API
      resources :analytics, only: [] do
        collection do
          get :overview
          get 'journeys/:id', action: :journey_analytics, as: :journey_analytics
          get 'campaigns/:id', action: :campaign_analytics, as: :campaign_analytics
          get 'funnels/:journey_id', action: :funnel_analytics, as: :funnel_analytics
          get 'ab_tests/:id', action: :ab_test_analytics, as: :ab_test_analytics
          get :comparative, action: :comparative_analytics
          get :trends
          get 'personas/:id/performance', action: :persona_performance, as: :persona_performance
          post :custom_report
          get :real_time
        end
      end
      
      # Campaign Management API
      resources :campaigns do
        member do
          post :activate
          post :pause
          get :analytics
          get :journeys
          post :journeys, action: :add_journey
          delete 'journeys/:journey_id', action: :remove_journey
        end
        
        collection do
          get :industries
          get :types
        end
        
        # Campaign Plans API
        resources :plans, controller: :campaign_plans do
          member do
            post :submit_for_review
            post :approve
            post :reject
            get :export
            get :notifications
            patch :auto_save
            post :save_as_template
            patch :reorder_phases
          end
        end
      end
      
      # Persona Management API
      resources :personas do
        member do
          get :campaigns
          get :performance
          post :clone
        end
        
        collection do
          get :templates
          post :from_template, action: :create_from_template
          get :analytics_overview
        end
      end
      
      # AI Suggestions API
      resources :journey_suggestions, only: [:index] do
        collection do
          get 'for_stage/:stage', action: :for_stage, as: :for_stage
          get 'for_step', action: :for_step
          post :bulk_suggestions
          post :personalized_suggestions
          post :feedback, action: :create_feedback
          get :feedback_analytics
          get :suggestion_history
          post :refresh_cache
        end
      end
      
      # Campaign Intake API
      namespace :campaign_intake, path: 'campaign-intake' do
        post :message
        post :threads, action: :save_thread
        get 'threads/:id', action: :get_thread
        get :questionnaire
        post :complete
      end
    end
    
    # Legacy API endpoints (redirect to v1)
    resources :journey_suggestions, only: [:index] do
      collection do
        get 'for_stage/:stage', action: :for_stage, as: :for_stage
        get 'for_step', action: :for_step
        post :feedback, action: :create_feedback
      end
    end
  end
  resources :journey_templates do
    member do
      post :clone
      post :use_template
      get :builder
      get :builder_react
    end
  end

  # Campaign Plans Management
  resources :campaigns, only: [:index, :show] do
    collection do
      get :intake
    end
    resources :campaign_plans, path: 'plans', except: [:destroy] do
      member do
        get :dashboard
        post :submit_for_review
        post :approve
        post :reject
        get :export
        patch :reorder_phases
        post :save_as_template
      end
    end
  end
  
  # Direct campaign plan routes
  resources :campaign_plans, only: [:show, :edit, :update, :destroy] do
    member do
      get :dashboard
      post :submit_for_review
      post :approve
      post :reject
      get :export
      patch :reorder_phases
      post :save_as_template
    end
    
    # Plan Comments
    resources :plan_comments, path: 'comments', only: [:create, :update, :destroy]
  end
  
  # Plan Templates Management
  resources :plan_templates, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do
      get :preview
      post :clone
      post :activate
      post :deactivate
    end
    
    collection do
      get :public_templates
      get :user_templates
    end
  end

  # A/B Testing Management
  resources :ab_tests, path: 'ab-tests' do
    member do
      post :start
      post :pause 
      post :resume
      post :complete
      get :results
      get :analysis
      get :live_metrics
      post :declare_winner
    end
    
    collection do
      get :dashboard, action: :index
    end
  end
  
  # Campaign-scoped A/B tests
  resources :campaigns, only: [:index, :show] do
    resources :ab_tests, path: 'ab-tests', except: [:show] do
      member do
        post :start
        post :pause
        post :resume
        post :complete
      end
    end
  end

  # Journey management and AI suggestions
  resources :journeys, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do
      post :duplicate
      post :publish  
      post :archive
      get :builder
    end
    # Journey suggestions endpoints
    resources :suggestions, controller: 'journey_suggestions', only: [:index] do
      collection do
        get 'for_stage/:stage', action: :for_stage, as: :for_stage
        get 'for_step/:step_id', action: :for_step, as: :for_step
        post :feedback, action: :create_feedback
        get :insights
        get :analytics
        delete :cache, action: :clear_cache
      end
    end
    
    # Journey steps management  
    resources :steps, controller: 'journey_steps', except: [:index] do
      member do
        patch :move
        post :duplicate
      end
    end
  end
  # Custom admin interface as fallback  
  get '/admin', to: 'admin#index'
  get '/admin/users', to: 'admin#users'
  get '/admin/activities', to: 'admin#activities'
  get '/admin/audit_logs', to: 'admin#audit_logs'
  
  # mount RailsAdmin::Engine => '/admin', as: 'rails_admin' if Rails.env.development? || Rails.env.production?
  root "home#index"
  get "typography-demo", to: "home#typography_demo"
  
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
  
  # Error pages
  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable_entity'
  get '/500', to: 'errors#internal_server_error'
  post '/error_report', to: 'errors#report_error'
  
  # Demo routes (development only)
  get 'loading_demo', to: 'home#loading_demo' if Rails.env.development?

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
