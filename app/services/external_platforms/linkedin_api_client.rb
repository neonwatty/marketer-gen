# frozen_string_literal: true

# LinkedIn API client for professional network marketing and analytics
# Supports LinkedIn Marketing API, Organization API, and Campaign Manager API
class ExternalPlatforms::LinkedinApiClient < ExternalPlatforms::BaseApiClient
  BASE_URL = 'https://api.linkedin.com'
  API_VERSION = 'v2'

  def initialize(access_token)
    @access_token = access_token
    super('LinkedIn', "#{BASE_URL}/#{API_VERSION}")
  end

  # Profile and organization management
  def get_profile
    get_request('/people/~', {
      projection: '(id,firstName,lastName,profilePicture(displayImage~:playableStreams))'
    })
  end

  def get_organizations(role = nil)
    params = { q: 'roleAssignee' }
    params[:role] = role if role
    params[:projection] = '(elements*(organization~(id,name,localizedName,description,logoV2(original~:playableStreams)),organizationalTarget~(id,name),role))'

    get_request('/organizationAcls', params)
  end

  def get_organization_info(organization_id)
    get_request("/organizations/#{organization_id}", {
      projection: '(id,name,localizedName,description,logoV2,website,industries,specialties,locations)'
    })
  end

  # Campaign management
  def get_ad_accounts(organization_id = nil)
    params = { q: 'search' }
    params[:search] = { status: { values: ['ACTIVE', 'DRAFT'] } }
    params[:search][:reference] = "urn:li:organization:#{organization_id}" if organization_id

    get_request('/adAccountsV2', params)
  end

  def get_campaigns(ad_account_id, options = {})
    params = {
      q: 'search',
      search: {
        account: { values: ["urn:li:sponsoredAccount:#{ad_account_id}"] },
        status: { values: options[:status] || ['ACTIVE', 'PAUSED', 'DRAFT'] }
      },
      projection: campaign_projection,
      count: options[:limit] || 50
    }

    get_request('/adCampaignsV2', params)
  end

  def create_campaign(campaign_data)
    post_request('/adCampaignsV2', campaign_data)
  end

  def update_campaign(campaign_id, campaign_data)
    post_request("/adCampaignsV2/#{campaign_id}", campaign_data, method: :patch)
  end

  def get_campaign_groups(ad_account_id, options = {})
    params = {
      q: 'search',
      search: {
        account: { values: ["urn:li:sponsoredAccount:#{ad_account_id}"] },
        status: { values: options[:status] || ['ACTIVE', 'PAUSED'] }
      },
      projection: campaign_group_projection,
      count: options[:limit] || 50
    }

    get_request('/adCampaignGroupsV2', params)
  end

  # Creative management
  def get_creatives(campaign_id, options = {})
    params = {
      q: 'search',
      search: {
        campaigns: { values: ["urn:li:sponsoredCampaign:#{campaign_id}"] },
        status: { values: options[:status] || ['ACTIVE', 'PAUSED'] }
      },
      projection: creative_projection,
      count: options[:limit] || 50
    }

    get_request('/adCreativesV2', params)
  end

  # Analytics and insights
  def get_campaign_analytics(campaign_id, date_range = {}, pivot = 'CAMPAIGN')
    params = {
      q: 'analytics',
      pivot: pivot,
      dateRange: format_date_range(date_range),
      campaigns: ["urn:li:sponsoredCampaign:#{campaign_id}"],
      fields: analytics_fields.join(',')
    }

    get_request('/adAnalyticsV2', params)
  end

  def get_account_analytics(ad_account_id, date_range = {}, pivot = 'ACCOUNT')
    params = {
      q: 'analytics',
      pivot: pivot,
      dateRange: format_date_range(date_range),
      accounts: ["urn:li:sponsoredAccount:#{ad_account_id}"],
      fields: analytics_fields.join(',')
    }

    get_request('/adAnalyticsV2', params)
  end

  def get_demographic_analytics(campaign_id, date_range = {})
    params = {
      q: 'analytics',
      pivot: 'MEMBER_COMPANY_SIZE',
      dateRange: format_date_range(date_range),
      campaigns: ["urn:li:sponsoredCampaign:#{campaign_id}"],
      fields: 'dateRange,pivot,pivotValue,impressions,clicks,costInUsd,externalWebsiteConversions'
    }

    get_request('/adAnalyticsV2', params)
  end

  # Audience and targeting
  def get_targeting_facets(facet_type, locale = 'en_US')
    params = {
      facetType: facet_type,
      locale: locale
    }

    get_request('/targetingFacetsV2', params)
  end

  def get_audience_counts(targeting_criteria)
    post_request('/audienceCountsV2', {
      targetingCriteria: targeting_criteria
    })
  end

  # Conversion tracking
  def get_conversions(ad_account_id, date_range = {})
    params = {
      q: 'analytics',
      pivot: 'CONVERSION',
      dateRange: format_date_range(date_range),
      accounts: ["urn:li:sponsoredAccount:#{ad_account_id}"],
      fields: 'dateRange,pivot,pivotValue,externalWebsiteConversions,oneClickLeads,follows'
    }

    get_request('/adAnalyticsV2', params)
  end

  def get_conversion_tracking(conversion_id)
    get_request("/conversions/#{conversion_id}", {
      projection: '(id,name,account,rules,attribution)'
    })
  end

  # Content and organic posts
  def get_organization_posts(organization_id, options = {})
    params = {
      q: 'author',
      author: "urn:li:organization:#{organization_id}",
      count: options[:limit] || 50,
      projection: post_projection
    }
    params[:start] = options[:start] if options[:start]

    get_request('/shares', params)
  end

  def get_post_analytics(post_id)
    get_request("/organizationalEntityShareStatistics/#{post_id}", {
      projection: '(totalShareStatistics,clickCount,commentCount,engagement,impressionCount,likeCount,shareCount)'
    })
  end

  # Follower analytics
  def get_follower_statistics(organization_id, date_range = {})
    params = {
      q: 'organizationalEntity',
      organizationalEntity: "urn:li:organization:#{organization_id}"
    }
    
    if date_range[:since] && date_range[:until]
      params[:timeIntervals] = format_time_intervals(date_range)
    end

    get_request('/networkSizes', params)
  end

  def get_follower_demographics(organization_id)
    get_request('/followerStatistics', {
      q: 'organizationalEntity',
      organizationalEntity: "urn:li:organization:#{organization_id}",
      projection: '(elements*(followerCounts,organizationalEntity))'
    })
  end

  # Lead generation
  def get_lead_gen_forms(ad_account_id)
    params = {
      q: 'account',
      account: "urn:li:sponsoredAccount:#{ad_account_id}",
      projection: '(elements*(id,name,locale,status,content))'
    }

    get_request('/leadGenForms', params)
  end

  def get_form_responses(form_id, options = {})
    params = {
      q: 'leadGenForm',
      leadGenForm: "urn:li:leadGenForm:#{form_id}",
      projection: '(elements*(id,submittedAt,formResponse))',
      count: options[:limit] || 100
    }
    params[:start] = options[:start] if options[:start]

    get_request('/leadFormResponses', params)
  end

  protected

  # Override default headers for LinkedIn API
  def default_headers
    super.merge({
      'Authorization' => "Bearer #{@access_token}",
      'LinkedIn-Version' => '202401',
      'X-Restli-Protocol-Version' => '2.0.0'
    })
  end

  # LinkedIn health check
  def health_check_path
    '/people/~'
  end

  private

  def campaign_projection
    '(id,name,status,type,costType,targetingCriteria,createdTime,lastModifiedTime,campaignGroup,dailyBudget,unitCost,objectives)'
  end

  def campaign_group_projection
    '(id,name,status,account,totalBudget,dailyBudget,runSchedule,createdTime,lastModifiedTime)'
  end

  def creative_projection
    '(id,campaign,status,createdTime,lastModifiedTime,intendedStatus,content)'
  end

  def post_projection
    '(id,author,created,distribution,text,content,commentary)'
  end

  def analytics_fields
    %w[
      dateRange impressions clicks shares follows costInUsd
      externalWebsiteConversions oneClickLeads totalEngagements
      reactions comments shares videoViews
    ]
  end

  def format_date_range(date_range)
    if date_range.blank?
      {
        start: { day: 30.days.ago.day, month: 30.days.ago.month, year: 30.days.ago.year },
        end: { day: Date.current.day, month: Date.current.month, year: Date.current.year }
      }
    else
      start_date = date_range[:since] || 30.days.ago
      end_date = date_range[:until] || Date.current
      
      start_date = Date.parse(start_date) if start_date.is_a?(String)
      end_date = Date.parse(end_date) if end_date.is_a?(String)

      {
        start: { day: start_date.day, month: start_date.month, year: start_date.year },
        end: { day: end_date.day, month: end_date.month, year: end_date.year }
      }
    end
  end

  def format_time_intervals(date_range)
    start_date = date_range[:since] || 30.days.ago
    end_date = date_range[:until] || Date.current
    
    start_date = Date.parse(start_date) if start_date.is_a?(String)
    end_date = Date.parse(end_date) if end_date.is_a?(String)

    # LinkedIn expects millisecond timestamps
    {
      timeIntervals: {
        start: start_date.beginning_of_day.to_i * 1000,
        end: end_date.end_of_day.to_i * 1000
      }
    }
  end

  # Override error handling for LinkedIn specific errors
  def extract_error_message(body)
    return 'Unknown error' unless body.is_a?(Hash)

    if body['message']
      message = body['message']
      status = body['status']
      service_error_code = body['serviceErrorCode']

      result = message
      result += " (Status: #{status})" if status
      result += " (Service Error Code: #{service_error_code})" if service_error_code
      result
    elsif body['errorDetails']
      details = body['errorDetails']
      if details.is_a?(Array) && details.first
        details.first['message'] || 'LinkedIn API error'
      else
        'LinkedIn API error'
      end
    else
      super(body)
    end
  end

  # LinkedIn specific retry logic
  def retriable_request?(env)
    # Don't retry authentication errors
    return false if env.status == 401 || env.status == 403

    # LinkedIn uses 429 for throttling
    return true if env.status == 429

    # Check for specific LinkedIn throttling errors
    if env.body.is_a?(Hash) && env.body['status']
      return true if env.body['status'] == 429
    end

    super(env)
  end

  def handle_client_response_error(response)
    if response.status == 429 ||
       (response.body.is_a?(Hash) && response.body['status'] == 429)
      
      retry_after = determine_retry_after(response.headers) || 300
      Rails.logger.warn "LinkedIn API rate limited. Retry after #{retry_after} seconds"
      
      return {
        success: false,
        error: 'rate_limited',
        message: 'LinkedIn API rate limit exceeded',
        platform: platform_name,
        retry_after: retry_after,
        status: response.status
      }
    end

    super(response)
  end
end