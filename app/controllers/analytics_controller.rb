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

  def authenticate_user!
    # This assumes you have a current_user method from your authentication system
    return if current_user

    render json: { error: "Authentication required" }, status: :unauthorized
  end
end
