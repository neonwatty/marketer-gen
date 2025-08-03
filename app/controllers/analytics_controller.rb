# frozen_string_literal: true

# Controller for Google Analytics integrations providing API endpoints
# for Google Ads, Google Analytics 4, and Search Console data
class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_date_range, only: [ :google_ads_performance, :ga4_analytics, :search_console_data ]
  before_action :validate_google_integration, only: [ :google_ads_performance, :ga4_analytics, :search_console_data ]

  # POST /analytics/google_ads/performance
  def google_ads_performance
    service = Analytics::GoogleAdsService.new(
      user_id: current_user.id,
      customer_id: params[:customer_id]
    )

    result = service.campaign_performance(
      start_date: @start_date,
      end_date: @end_date,
      metrics: params[:metrics] || Analytics::GoogleAdsService::SUPPORTED_METRICS
    )

    render json: result
  rescue Analytics::GoogleAdsService::GoogleAdsApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # POST /analytics/google_ads/conversions
  def google_ads_conversions
    service = Analytics::GoogleAdsService.new(
      user_id: current_user.id,
      customer_id: params[:customer_id]
    )

    result = service.conversion_data(
      start_date: @start_date,
      end_date: @end_date,
      conversion_actions: params[:conversion_actions] || Analytics::GoogleAdsService::CONVERSION_ACTIONS
    )

    render json: result
  rescue Analytics::GoogleAdsService::GoogleAdsApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # POST /analytics/ga4/website_analytics
  def ga4_analytics
    service = Analytics::GoogleAnalyticsService.new(
      user_id: current_user.id,
      property_id: params[:property_id]
    )

    result = service.website_analytics(
      start_date: @start_date,
      end_date: @end_date,
      metrics: params[:metrics] || Analytics::GoogleAnalyticsService::STANDARD_METRICS,
      dimensions: params[:dimensions] || Analytics::GoogleAnalyticsService::STANDARD_DIMENSIONS
    )

    render json: result
  rescue Analytics::GoogleAnalyticsService::GoogleAnalyticsApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # POST /analytics/ga4/user_journey
  def ga4_user_journey
    service = Analytics::GoogleAnalyticsService.new(
      user_id: current_user.id,
      property_id: params[:property_id]
    )

    result = service.user_journey_analysis(
      start_date: @start_date,
      end_date: @end_date,
      conversion_events: params[:conversion_events] || Analytics::GoogleAnalyticsService::CONVERSION_EVENTS
    )

    render json: result
  rescue Analytics::GoogleAnalyticsService::GoogleAnalyticsApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # POST /analytics/search_console/search_analytics
  def search_console_data
    service = Analytics::GoogleSearchConsoleService.new(
      user_id: current_user.id,
      site_url: params[:site_url]
    )

    result = service.search_analytics(
      start_date: @start_date,
      end_date: @end_date,
      dimensions: params[:dimensions] || %w[query],
      search_type: params[:search_type] || "web"
    )

    render json: result
  rescue Analytics::GoogleSearchConsoleService::SearchConsoleApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # POST /analytics/search_console/keyword_rankings
  def keyword_rankings
    service = Analytics::GoogleSearchConsoleService.new(
      user_id: current_user.id,
      site_url: params[:site_url]
    )

    result = service.keyword_rankings(
      start_date: @start_date,
      end_date: @end_date,
      queries: params[:queries] || [],
      country: params[:country],
      device: params[:device]
    )

    render json: result
  rescue Analytics::GoogleSearchConsoleService::SearchConsoleApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # POST /analytics/attribution/cross_platform
  def cross_platform_attribution
    service = Analytics::AttributionModelingService.new(
      user_id: current_user.id,
      google_ads_customer_id: params[:google_ads_customer_id],
      ga4_property_id: params[:ga4_property_id],
      search_console_site: params[:search_console_site]
    )

    result = service.cross_platform_attribution(
      start_date: @start_date,
      end_date: @end_date,
      attribution_model: params[:attribution_model] || "last_click",
      conversion_events: params[:conversion_events] || Analytics::AttributionModelingService::CONVERSION_EVENTS
    )

    render json: result
  rescue Analytics::AttributionModelingService::AttributionError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # GET /analytics/google_oauth/authorize
  def google_oauth_authorize
    service = Analytics::GoogleOauthService.new(
      user_id: current_user.id,
      integration_type: params[:integration_type]&.to_sym || :google_ads
    )

    authorization_url = service.authorization_url(state: params[:state])
    render json: { authorization_url: authorization_url }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :bad_request
  end

  # POST /analytics/google_oauth/callback
  def google_oauth_callback
    service = Analytics::GoogleOauthService.new(
      user_id: current_user.id,
      integration_type: params[:integration]&.to_sym || :google_ads
    )

    result = service.exchange_code_for_tokens(params[:code], params[:state])
    render json: { success: true, token_info: result }
  rescue Analytics::GoogleOauthService::GoogleApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # DELETE /analytics/google_oauth/revoke
  def google_oauth_revoke
    service = Analytics::GoogleOauthService.new(
      user_id: current_user.id,
      integration_type: params[:integration_type]&.to_sym || :google_ads
    )

    result = service.revoke_access
    render json: { success: result }
  rescue Analytics::GoogleOauthService::GoogleApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # GET /analytics/google_ads/accounts
  def google_ads_accounts
    service = Analytics::GoogleAdsService.new(
      user_id: current_user.id
    )

    result = service.accessible_accounts
    render json: { accounts: result }
  rescue Analytics::GoogleAdsService::GoogleAdsApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # GET /analytics/ga4/properties
  def ga4_properties
    service = Analytics::GoogleAnalyticsService.new(
      user_id: current_user.id,
      property_id: nil # Will fetch all accessible properties
    )

    result = service.accessible_properties
    render json: { properties: result }
  rescue Analytics::GoogleAnalyticsService::GoogleAnalyticsApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  # GET /analytics/search_console/sites
  def search_console_sites
    service = Analytics::GoogleSearchConsoleService.new(
      user_id: current_user.id
    )

    result = service.verified_sites
    render json: { sites: result }
  rescue Analytics::GoogleSearchConsoleService::SearchConsoleApiError => e
    render json: { error: e.message, error_type: e.error_type }, status: :unprocessable_entity
  end

  private

  def set_date_range
    @start_date = params[:start_date] || 30.days.ago.strftime("%Y-%m-%d")
    @end_date = params[:end_date] || Date.current.strftime("%Y-%m-%d")

    # Validate date format
    Date.parse(@start_date)
    Date.parse(@end_date)
  rescue Date::Error
    render json: { error: "Invalid date format. Use YYYY-MM-DD" }, status: :bad_request
  end

  def validate_google_integration
    # Check if user has valid Google OAuth tokens
    oauth_service = Analytics::GoogleOauthService.new(
      user_id: current_user.id,
      integration_type: determine_integration_type
    )

    unless oauth_service.authenticated?
      render json: {
        error: "Google authentication required",
        authorization_url: oauth_service.authorization_url
      }, status: :unauthorized
    end
  end

  def determine_integration_type
    case action_name
    when /google_ads/
      :google_ads
    when /ga4/
      :google_analytics
    when /search_console/
      :search_console
    else
      :google_ads
    end
  end

  # GET /analytics/dashboard
  def dashboard
    @brand = current_user.brands.find_by(id: params[:brand_id])
    @initial_metrics = fetch_initial_dashboard_data(@brand) if @brand
  end

  # POST /analytics/dashboard/data
  def dashboard_data
    brand = current_user.brands.find_by(id: params[:brand_id])
    
    unless brand
      return render json: { error: "Brand not found" }, status: :not_found
    end

    time_range = params[:time_range] || '30d'
    
    # Fetch data from all integrated sources
    dashboard_metrics = {
      social_media: fetch_social_media_metrics(brand, time_range),
      email: fetch_email_metrics(brand, time_range),
      google_analytics: fetch_google_analytics_metrics(brand, time_range),
      crm: fetch_crm_metrics(brand, time_range),
      summary: fetch_summary_metrics(brand, time_range),
      timestamp: Time.current.iso8601
    }

    render json: dashboard_metrics
  rescue StandardError => e
    Rails.logger.error "Dashboard data fetch failed: #{e.message}"
    render json: { error: "Failed to fetch dashboard data" }, status: :internal_server_error
  end

  # POST /analytics/performance
  def performance
    # Log performance metrics for monitoring
    performance_data = {
      component: params[:component],
      duration: params[:duration],
      user_id: params[:user_id],
      brand_id: params[:brand_id],
      timestamp: params[:timestamp],
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    }

    Rails.logger.info "Performance metric: #{performance_data.to_json}"
    
    # Store in database if needed for analysis
    # PerformanceMetric.create!(performance_data)
    
    render json: { success: true }
  end

  private

  def fetch_initial_dashboard_data(brand)
    return {} unless brand

    {
      social_media: fetch_social_media_metrics(brand, '7d'),
      email: fetch_email_metrics(brand, '7d'),
      google_analytics: fetch_google_analytics_metrics(brand, '7d'),
      crm: fetch_crm_metrics(brand, '7d'),
      summary: fetch_summary_metrics(brand, '7d')
    }
  rescue StandardError => e
    Rails.logger.error "Initial dashboard data fetch failed: #{e.message}"
    {}
  end

  def fetch_social_media_metrics(brand, time_range)
    service = Analytics::SocialMediaIntegrationService.new(brand)
    service.dashboard_metrics(time_range)
  rescue StandardError => e
    Rails.logger.error "Social media metrics fetch failed: #{e.message}"
    { error: e.message }
  end

  def fetch_email_metrics(brand, time_range)
    service = Analytics::EmailAnalyticsService.new(brand)
    service.dashboard_metrics(time_range)
  rescue StandardError => e
    Rails.logger.error "Email metrics fetch failed: #{e.message}"
    { error: e.message }
  end

  def fetch_google_analytics_metrics(brand, time_range)
    # Check if Google Analytics is connected for this brand
    return { error: "Google Analytics not connected" } unless brand.respond_to?(:google_analytics_connected?) && brand.google_analytics_connected?

    service = Analytics::GoogleAnalyticsService.new(
      user_id: current_user.id,
      property_id: brand.respond_to?(:google_analytics_property_id) ? brand.google_analytics_property_id : nil
    )
    service.dashboard_metrics(time_range) if service.respond_to?(:dashboard_metrics)
  rescue StandardError => e
    Rails.logger.error "Google Analytics metrics fetch failed: #{e.message}"
    { error: e.message }
  end

  def fetch_crm_metrics(brand, time_range)
    service = Analytics::CrmAnalyticsService.new(brand)
    service.dashboard_metrics(time_range)
  rescue StandardError => e
    Rails.logger.error "CRM metrics fetch failed: #{e.message}"
    { error: e.message }
  end

  def fetch_summary_metrics(brand, time_range)
    {
      total_leads: brand.respond_to?(:crm_leads) ? brand.crm_leads.where("created_at > ?", parse_time_range(time_range)).count : 0,
      total_campaigns: brand.campaigns.where("created_at > ?", parse_time_range(time_range)).count,
      total_revenue: calculate_total_revenue(brand, time_range),
      conversion_rate: calculate_conversion_rate(brand, time_range)
    }
  rescue StandardError => e
    Rails.logger.error "Summary metrics fetch failed: #{e.message}"
    {}
  end

  def parse_time_range(time_range)
    case time_range
    when '24h', '1d'
      1.day.ago
    when '7d'
      7.days.ago
    when '30d'
      30.days.ago
    when '90d'
      90.days.ago
    when '1y'
      1.year.ago
    else
      30.days.ago
    end
  end

  def calculate_total_revenue(brand, time_range)
    # Calculate revenue from CRM opportunities
    start_date = parse_time_range(time_range)
    if brand.respond_to?(:crm_opportunities)
      brand.crm_opportunities
           .where("created_at > ? AND status = ?", start_date, "won")
           .sum(:value) || 0
    else
      0
    end
  end

  def calculate_conversion_rate(brand, time_range)
    start_date = parse_time_range(time_range)
    total_leads = brand.respond_to?(:crm_leads) ? brand.crm_leads.where("created_at > ?", start_date).count : 0
    converted_leads = if brand.respond_to?(:crm_opportunities)
                       brand.crm_opportunities
                            .where("created_at > ? AND status = ?", start_date, "won")
                            .count
                     else
                       0
                     end
    
    return 0 if total_leads.zero?
    
    (converted_leads.to_f / total_leads * 100).round(2)
  end

  def authenticate_user!
    # This assumes you have a current_user method from your authentication system
    return if current_user

    render json: { error: "Authentication required" }, status: :unauthorized
  end
end
