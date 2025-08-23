# frozen_string_literal: true

# Google Ads API client for advertising data and campaign management
# Supports Google Ads API v16 with GAQL (Google Ads Query Language)
class ExternalPlatforms::GoogleAdsApiClient < ExternalPlatforms::BaseApiClient
  BASE_URL = 'https://googleads.googleapis.com'
  API_VERSION = 'v16'

  def initialize(access_token, developer_token, customer_id, refresh_token = nil)
    @access_token = access_token
    @developer_token = developer_token
    @customer_id = customer_id
    @refresh_token = refresh_token
    super('Google Ads', "#{BASE_URL}/#{API_VERSION}")
  end

  # Customer and account management
  def get_customer_info(customer_id = @customer_id)
    query = "SELECT customer.id, customer.descriptive_name, customer.currency_code, customer.time_zone FROM customer WHERE customer.id = #{customer_id}"
    search_request(customer_id, query)
  end

  def get_accessible_customers
    get_request('/customers:listAccessibleCustomers')
  end

  # Campaign management
  def get_campaigns(customer_id = @customer_id, options = {})
    fields = %w[
      campaign.id campaign.name campaign.status campaign.advertising_channel_type
      campaign.start_date campaign.end_date campaign.campaign_budget
      campaign.bidding_strategy_type campaign.target_cpa campaign.target_roas
    ]

    query = "SELECT #{fields.join(', ')} FROM campaign"
    query += " WHERE campaign.status != 'REMOVED'" unless options[:include_removed]
    query += " ORDER BY campaign.name"
    query += " LIMIT #{options[:limit]}" if options[:limit]

    search_request(customer_id, query)
  end

  def get_campaign_performance(customer_id, campaign_id = nil, date_range = {})
    fields = %w[
      campaign.id campaign.name metrics.impressions metrics.clicks
      metrics.cost_micros metrics.ctr metrics.average_cpc metrics.average_cpm
      metrics.conversions metrics.cost_per_conversion segments.date
    ]

    query = "SELECT #{fields.join(', ')} FROM campaign"
    conditions = ["campaign.status != 'REMOVED'"]
    
    if campaign_id
      conditions << "campaign.id = #{campaign_id}"
    end

    if date_range[:since] && date_range[:until]
      conditions << "segments.date BETWEEN '#{format_date(date_range[:since])}' AND '#{format_date(date_range[:until])}'"
    end

    query += " WHERE #{conditions.join(' AND ')}" if conditions.any?
    query += " ORDER BY segments.date DESC"

    search_request(customer_id, query)
  end

  # Ad groups and keywords
  def get_ad_groups(customer_id, campaign_id, options = {})
    fields = %w[
      ad_group.id ad_group.name ad_group.status ad_group.type
      ad_group.target_cpa_micros ad_group.target_cpm_micros
      campaign.id campaign.name
    ]

    query = "SELECT #{fields.join(', ')} FROM ad_group"
    conditions = ["ad_group.status != 'REMOVED'"]
    conditions << "campaign.id = #{campaign_id}" if campaign_id

    query += " WHERE #{conditions.join(' AND ')}"
    query += " ORDER BY ad_group.name"
    query += " LIMIT #{options[:limit]}" if options[:limit]

    search_request(customer_id, query)
  end

  def get_keywords(customer_id, ad_group_id = nil, options = {})
    fields = %w[
      ad_group_criterion.keyword.text ad_group_criterion.keyword.match_type
      ad_group_criterion.status ad_group_criterion.quality_info.quality_score
      ad_group.id ad_group.name campaign.id campaign.name
      metrics.impressions metrics.clicks metrics.cost_micros
    ]

    query = "SELECT #{fields.join(', ')} FROM keyword_view"
    conditions = ["ad_group_criterion.status != 'REMOVED'"]
    conditions << "ad_group.id = #{ad_group_id}" if ad_group_id

    if date_range = options[:date_range]
      conditions << "segments.date BETWEEN '#{format_date(date_range[:since])}' AND '#{format_date(date_range[:until])}'"
    end

    query += " WHERE #{conditions.join(' AND ')}"
    query += " ORDER BY metrics.impressions DESC"
    query += " LIMIT #{options[:limit] || 1000}"

    search_request(customer_id, query)
  end

  # Ad performance and insights
  def get_ad_performance(customer_id, date_range = {})
    fields = %w[
      ad_group_ad.ad.id ad_group_ad.ad.name ad_group_ad.status
      ad_group_ad.ad.type ad_group.id ad_group.name
      campaign.id campaign.name metrics.impressions metrics.clicks
      metrics.cost_micros metrics.conversions segments.date
    ]

    query = "SELECT #{fields.join(', ')} FROM ad_group_ad"
    conditions = ["ad_group_ad.status != 'REMOVED'"]

    if date_range[:since] && date_range[:until]
      conditions << "segments.date BETWEEN '#{format_date(date_range[:since])}' AND '#{format_date(date_range[:until])}'"
    end

    query += " WHERE #{conditions.join(' AND ')}"
    query += " ORDER BY metrics.impressions DESC"

    search_request(customer_id, query)
  end

  # Audience and demographic insights
  def get_demographic_performance(customer_id, date_range = {})
    fields = %w[
      campaign.id campaign.name ad_group.id ad_group.name
      segments.age_range segments.gender metrics.impressions
      metrics.clicks metrics.cost_micros metrics.conversions
    ]

    query = "SELECT #{fields.join(', ')} FROM age_range_view"
    conditions = ["campaign.status != 'REMOVED'"]

    if date_range[:since] && date_range[:until]
      conditions << "segments.date BETWEEN '#{format_date(date_range[:since])}' AND '#{format_date(date_range[:until])}'"
    end

    query += " WHERE #{conditions.join(' AND ')}"
    query += " ORDER BY metrics.impressions DESC"

    search_request(customer_id, query)
  end

  # Geographic performance
  def get_geographic_performance(customer_id, date_range = {})
    fields = %w[
      campaign.id campaign.name segments.geo_target_region
      metrics.impressions metrics.clicks metrics.cost_micros
      metrics.conversions segments.date
    ]

    query = "SELECT #{fields.join(', ')} FROM geographic_view"
    conditions = ["campaign.status != 'REMOVED'"]

    if date_range[:since] && date_range[:until]
      conditions << "segments.date BETWEEN '#{format_date(date_range[:since])}' AND '#{format_date(date_range[:until])}'"
    end

    query += " WHERE #{conditions.join(' AND ')}"
    query += " ORDER BY metrics.impressions DESC"
    query += " LIMIT 100"

    search_request(customer_id, query)
  end

  # Search term insights
  def get_search_terms(customer_id, date_range = {})
    fields = %w[
      search_term_view.search_term search_term_view.status
      campaign.id campaign.name ad_group.id ad_group.name
      metrics.impressions metrics.clicks metrics.cost_micros
    ]

    query = "SELECT #{fields.join(', ')} FROM search_term_view"
    conditions = ["search_term_view.status != 'NONE'"]

    if date_range[:since] && date_range[:until]
      conditions << "segments.date BETWEEN '#{format_date(date_range[:since])}' AND '#{format_date(date_range[:until])}'"
    end

    query += " WHERE #{conditions.join(' AND ')}"
    query += " ORDER BY metrics.impressions DESC"
    query += " LIMIT 1000"

    search_request(customer_id, query)
  end

  # Conversion tracking
  def get_conversions(customer_id, date_range = {})
    fields = %w[
      campaign.id campaign.name segments.conversion_action_name
      segments.conversion_action_category metrics.conversions
      metrics.conversions_value metrics.cost_per_conversion
      segments.date
    ]

    query = "SELECT #{fields.join(', ')} FROM campaign"
    conditions = ["campaign.status != 'REMOVED'", "metrics.conversions > 0"]

    if date_range[:since] && date_range[:until]
      conditions << "segments.date BETWEEN '#{format_date(date_range[:since])}' AND '#{format_date(date_range[:until])}'"
    end

    query += " WHERE #{conditions.join(' AND ')}"
    query += " ORDER BY metrics.conversions DESC"

    search_request(customer_id, query)
  end

  # Account budget and billing
  def get_account_budget(customer_id = @customer_id)
    fields = %w[
      account_budget.id account_budget.billing_setup account_budget.status
      account_budget.name account_budget.approved_spending_limit_micros
      account_budget.adjusted_spending_limit_micros
    ]

    query = "SELECT #{fields.join(', ')} FROM account_budget"
    query += " WHERE account_budget.status != 'CANCELLED'"

    search_request(customer_id, query)
  end

  protected

  # Override default headers for Google Ads API
  def default_headers
    super.merge({
      'Authorization' => "Bearer #{@access_token}",
      'developer-token' => @developer_token,
      'login-customer-id' => @customer_id.to_s
    })
  end

  # Google Ads health check
  def health_check_path
    "/customers/#{@customer_id}/googleAds:search"
  end

  # Perform search request using GAQL
  def search_request(customer_id, query)
    post_request("/customers/#{customer_id}/googleAds:search", {
      query: query,
      validateOnly: false,
      returnTotalResultsCount: true
    })
  end

  private

  def format_date(date)
    case date
    when Date, Time, DateTime
      date.strftime('%Y-%m-%d')
    when String
      date
    else
      Date.current.strftime('%Y-%m-%d')
    end
  end

  # Override error handling for Google Ads specific errors
  def extract_error_message(body)
    return 'Unknown error' unless body.is_a?(Hash)

    if body['error']
      error = body['error']
      message = error['message'] || 'Google Ads API error'
      code = error['code']
      details = error['details']

      result = message
      result += " (Code: #{code})" if code

      if details && details.is_a?(Array)
        details.each do |detail|
          if detail['errors']
            detail['errors'].each do |err|
              result += " - #{err['message']}" if err['message']
            end
          end
        end
      end

      result
    else
      super(body)
    end
  end

  # Google Ads specific retry logic
  def retriable_request?(env)
    # Don't retry authentication errors
    return false if env.status == 401

    # Retry on quota exceeded (Google uses 429)
    return true if env.status == 429

    # Retry on specific Google Ads errors
    if env.body.is_a?(Hash) && env.body['error']
      error_code = env.body.dig('error', 'code')
      return true if error_code.in?(['RATE_LIMIT_EXCEEDED', 'QUOTA_EXCEEDED'])
    end

    super(env)
  end

  def handle_client_response_error(response)
    if response.status == 429 || 
       (response.body.is_a?(Hash) && response.body.dig('error', 'code').in?(['RATE_LIMIT_EXCEEDED', 'QUOTA_EXCEEDED']))
      
      retry_after = determine_retry_after(response.headers) || 60
      Rails.logger.warn "Google Ads API quota/rate limit exceeded. Retry after #{retry_after} seconds"
      
      return {
        success: false,
        error: 'quota_exceeded',
        message: 'API quota or rate limit exceeded',
        platform: platform_name,
        retry_after: retry_after,
        status: response.status
      }
    end

    super(response)
  end
end