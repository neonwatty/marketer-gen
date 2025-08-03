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
    
    # Social Media Integrations
    resources :social_media_integrations, path: 'social-media' do
      member do
        post :refresh_token
        post :sync_metrics
      end
      collection do
        post :sync_all
      end
    end
    
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
      
      # Analytics Dashboard API
      namespace :analytics do
        get :dashboard, controller: :analytics
        post 'dashboard/data', action: :dashboard_data, controller: :analytics
        post :performance, controller: :analytics
      end

      # Google Analytics Integration API
      namespace :google_analytics, path: 'google-analytics' do
        # Google OAuth Routes
        get 'oauth/authorize', action: :google_oauth_authorize, controller: :analytics
        post 'oauth/callback', action: :google_oauth_callback, controller: :analytics
        delete 'oauth/revoke', action: :google_oauth_revoke, controller: :analytics
        
        # Google Ads API Routes
        namespace :google_ads, path: 'google-ads' do
          get :accounts, action: :google_ads_accounts, controller: :analytics
          post :performance, action: :google_ads_performance, controller: :analytics
          post :conversions, action: :google_ads_conversions, controller: :analytics
          post :budget_monitoring, action: :google_ads_budget_monitoring, controller: :analytics
          post :keyword_performance, action: :google_ads_keyword_performance, controller: :analytics
          post :audience_insights, action: :google_ads_audience_insights, controller: :analytics
        end
        
        # Google Analytics 4 (GA4) API Routes
        namespace :ga4 do
          get :properties, action: :ga4_properties, controller: :analytics
          post :website_analytics, action: :ga4_analytics, controller: :analytics
          post :user_journey, action: :ga4_user_journey, controller: :analytics
          post :audience_insights, action: :ga4_audience_insights, controller: :analytics
          post :ecommerce, action: :ga4_ecommerce, controller: :analytics
          post :realtime, action: :ga4_realtime, controller: :analytics
          post :cohort_analysis, action: :ga4_cohort_analysis, controller: :analytics
        end
        
        # Google Search Console API Routes
        namespace :search_console, path: 'search-console' do
          get :sites, action: :search_console_sites, controller: :analytics
          post :search_analytics, action: :search_console_data, controller: :analytics
          post :keyword_rankings, action: :keyword_rankings, controller: :analytics
          post :page_performance, action: :search_console_page_performance, controller: :analytics
          post :search_appearance, action: :search_console_appearance, controller: :analytics
          post :indexing_status, action: :search_console_indexing, controller: :analytics
          post :mobile_usability, action: :search_console_mobile, controller: :analytics
          post :core_web_vitals, action: :search_console_vitals, controller: :analytics
        end
        
        # Cross-Platform Attribution Routes
        namespace :attribution do
          post :cross_platform, action: :cross_platform_attribution, controller: :analytics
          post :customer_journey, action: :customer_journey_analysis, controller: :analytics
          post :channel_interaction, action: :channel_interaction_analysis, controller: :analytics
          post :roas_analysis, action: :cross_platform_roas, controller: :analytics
          post :model_comparison, action: :attribution_model_comparison, controller: :analytics
        end
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
  
  # Analytics Dashboard
  get '/analytics/dashboard', to: 'analytics#dashboard', as: :analytics_dashboard

  # Social Media OAuth Callbacks
  get '/social_media/oauth_callback/:platform', to: 'social_media_integrations#oauth_callback', 
      as: :social_media_oauth_callback

  # Email Platform Webhooks
  namespace :webhooks do
    post '/email/:platform/:integration_id', to: 'email_platforms#receive', 
         as: :email_platform,
         constraints: { platform: /mailchimp|sendgrid|constant_contact|campaign_monitor|activecampaign|klaviyo/ }
  end

  # Demo routes (development only)
  get 'loading_demo', to: 'home#loading_demo' if Rails.env.development?

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
