# frozen_string_literal: true

# Meta/Facebook API client for marketing and advertising data
# Supports Graph API, Marketing API, and Conversions API endpoints
class ExternalPlatforms::MetaApiClient < ExternalPlatforms::BaseApiClient
  BASE_URL = 'https://graph.facebook.com'
  API_VERSION = 'v19.0'

  def initialize(access_token, app_secret = nil)
    @access_token = access_token
    @app_secret = app_secret
    super('Meta', "#{BASE_URL}/#{API_VERSION}")
  end

  # Account and business management
  def get_ad_accounts
    get_request('/me/adaccounts', {
      fields: 'id,name,account_status,currency,timezone_name,business'
    })
  end

  def get_business_accounts
    get_request('/me/businesses', {
      fields: 'id,name,verification_status,created_time'
    })
  end

  # Campaign management
  def get_campaigns(ad_account_id, options = {})
    fields = options[:fields] || default_campaign_fields
    params = {
      fields: fields,
      limit: options[:limit] || 100
    }
    params[:filtering] = options[:filtering] if options[:filtering]

    get_request("/act_#{ad_account_id}/campaigns", params)
  end

  def create_campaign(campaign_data)
    ad_account_id = campaign_data.delete(:ad_account_id) || @ad_account_id
    post_request("/act_#{ad_account_id}/campaigns", campaign_data)
  end

  def update_campaign(campaign_id, campaign_data)
    post_request("/#{campaign_id}", campaign_data)
  end

  def get_campaign_performance(campaign_id, date_range = {})
    fields = %w[
      campaign_name spend impressions clicks cpc cpm ctr
      reach frequency actions conversions cost_per_conversion
      video_thruplay_watched_actions
    ].join(',')

    params = {
      fields: fields,
      time_range: format_date_range(date_range),
      time_increment: 'all_days'
    }

    get_request("/#{campaign_id}/insights", params)
  end

  # Ad sets and ads
  def get_ad_sets(campaign_id, options = {})
    fields = options[:fields] || default_adset_fields
    params = {
      fields: fields,
      limit: options[:limit] || 100
    }

    get_request("/#{campaign_id}/adsets", params)
  end

  def get_ads(ad_set_id, options = {})
    fields = options[:fields] || default_ad_fields
    params = {
      fields: fields,
      limit: options[:limit] || 100
    }

    get_request("/#{ad_set_id}/ads", params)
  end

  # Insights and analytics
  def get_account_insights(ad_account_id, date_range = {}, breakdown = nil)
    params = {
      level: 'account',
      fields: insight_fields,
      time_range: format_date_range(date_range),
      time_increment: date_range[:time_increment] || 'all_days'
    }
    params[:breakdowns] = breakdown if breakdown

    get_request("/act_#{ad_account_id}/insights", params)
  end

  def get_campaign_insights(campaign_id, date_range = {})
    params = {
      fields: insight_fields,
      time_range: format_date_range(date_range),
      time_increment: 'all_days'
    }

    get_request("/#{campaign_id}/insights", params)
  end

  # Audience insights
  def get_audience_insights(ad_account_id, audience_spec)
    post_request("/act_#{ad_account_id}/delivery_estimate", {
      targeting_spec: audience_spec,
      optimization_goal: 'IMPRESSIONS'
    })
  end

  # Creative management
  def get_ad_creatives(ad_account_id, options = {})
    fields = %w[
      id name object_story_spec image_hash image_url
      title body call_to_action_type status
    ].join(',')

    params = {
      fields: fields,
      limit: options[:limit] || 50
    }

    get_request("/act_#{ad_account_id}/adcreatives", params)
  end

  # Conversion tracking
  def get_conversions(ad_account_id, date_range = {})
    params = {
      level: 'ad',
      fields: 'ad_name,actions,conversions,cost_per_conversion',
      time_range: format_date_range(date_range),
      action_attribution_windows: ['7d_click', '1d_view']
    }

    get_request("/act_#{ad_account_id}/insights", params)
  end

  # Page insights (for organic content)
  def get_page_insights(page_id, metrics, date_range = {})
    params = {
      metric: Array(metrics).join(','),
      period: 'day'
    }
    params[:since] = date_range[:since] if date_range[:since]
    params[:until] = date_range[:until] if date_range[:until]

    get_request("/#{page_id}/insights", params)
  end

  # Platform-specific rate limit information
  def rate_limit_status
    response = get_request('/me', { fields: 'id' })
    
    if response[:success]
      headers = response[:headers]
      {
        available: true,
        platform: platform_name,
        usage: headers['x-business-use-case-usage'],
        app_usage: headers['x-app-usage'],
        ad_account_usage: headers['x-ad-account-usage'],
        reset_time: Time.current + 3600 # Meta resets hourly
      }
    else
      { available: false, platform: platform_name, error: response[:message] }
    end
  end

  protected

  # Override default headers to include authentication
  def default_headers
    super.merge({
      'Authorization' => "Bearer #{@access_token}"
    })
  end

  # Meta-specific health check
  def health_check_path
    '/me'
  end

  private

  def default_campaign_fields
    %w[
      id name status objective created_time updated_time
      start_time end_time budget_remaining daily_budget
      lifetime_budget bid_strategy buying_type
    ].join(',')
  end

  def default_adset_fields
    %w[
      id name status campaign_id created_time updated_time
      start_time end_time daily_budget lifetime_budget
      optimization_goal billing_event bid_amount targeting
    ].join(',')
  end

  def default_ad_fields
    %w[
      id name status adset_id created_time updated_time
      creative{id,name,image_hash,object_story_spec}
    ].join(',')
  end

  def insight_fields
    %w[
      spend impressions clicks unique_clicks cpc cpm ctr
      reach frequency actions conversions cost_per_conversion
      conversion_rate_ranking engagement_rate_ranking
      quality_ranking video_thruplay_watched_actions
    ].join(',')
  end

  def format_date_range(date_range)
    return { since: 30.days.ago.strftime('%Y-%m-%d'), until: Date.current.strftime('%Y-%m-%d') } if date_range.blank?

    range = {}
    range[:since] = date_range[:since].is_a?(Date) ? date_range[:since].strftime('%Y-%m-%d') : date_range[:since]
    range[:until] = date_range[:until].is_a?(Date) ? date_range[:until].strftime('%Y-%m-%d') : date_range[:until]
    range
  end

  # Override to handle Meta-specific error responses
  def extract_error_message(body)
    return 'Unknown error' unless body.is_a?(Hash)

    if body['error']
      error = body['error']
      message = error['message'] || error['error_description'] || 'Meta API error'
      code = error['code'] || error['error_code']
      subcode = error['error_subcode']

      result = message
      result += " (Code: #{code})" if code
      result += " (Subcode: #{subcode})" if subcode
      result
    else
      super(body)
    end
  end

  # Meta-specific retry logic
  def retriable_request?(env)
    # Don't retry if we have auth issues
    return false if env.status == 401 || env.status == 403

    # Retry on rate limits (Meta uses 429)
    return true if env.status == 429

    # Call parent for other retry logic
    super(env)
  end

  # Handle Meta rate limiting
  def handle_client_response_error(response)
    if response.status == 429
      retry_after = determine_retry_after(response.headers)
      Rails.logger.warn "Meta API rate limited. Retry after #{retry_after} seconds"
      
      return {
        success: false,
        error: 'rate_limited',
        message: 'Rate limit exceeded',
        platform: platform_name,
        retry_after: retry_after,
        status: response.status
      }
    end

    super(response)
  end
end