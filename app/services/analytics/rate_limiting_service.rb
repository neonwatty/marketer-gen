# frozen_string_literal: true

module Analytics
  # Enhanced rate limiting service supporting both social media platforms and Google APIs
  # with intelligent backoff, quota management, and error recovery
  module RateLimitingService
    extend ActiveSupport::Concern

    # Rate limiting configurations per platform
    RATE_LIMITS = {
      # Social Media Platforms
      "facebook" => {
        default: { requests: 600, window: 600 }, # 600 requests per 10 minutes
        insights: { requests: 200, window: 3600 }, # 200 requests per hour
        pages: { requests: 100, window: 600 }
      },
      "instagram" => {
        default: { requests: 240, window: 3600 }, # 240 requests per hour
        media: { requests: 100, window: 3600 },
        insights: { requests: 200, window: 3600 }
      },
      "linkedin" => {
        default: { requests: 500, window: 86400 }, # 500 requests per day
        analytics: { requests: 100, window: 3600 },
        posts: { requests: 300, window: 86400 }
      },
      "twitter" => {
        default: { requests: 300, window: 900 }, # 300 requests per 15 minutes
        tweets: { requests: 300, window: 900 },
        users: { requests: 75, window: 900 }
      },
      "tiktok" => {
        default: { requests: 1000, window: 86400 }, # 1000 requests per day
        videos: { requests: 100, window: 3600 },
        analytics: { requests: 200, window: 3600 }
      },
      # Google API Platforms
      "google_ads" => {
        default: { requests: 15000, window: 86400 }, # 15,000 requests per day
        search: { requests: 2000, window: 3600 }, # 2,000 requests per hour
        reports: { requests: 1000, window: 3600 }, # 1,000 requests per hour
        accounts: { requests: 100, window: 3600 } # 100 requests per hour
      },
      "google_analytics" => {
        default: { requests: 10000, window: 86400 }, # 10,000 requests per day
        reporting: { requests: 100, window: 100 }, # 100 requests per 100 seconds
        realtime: { requests: 10, window: 60 }, # 10 requests per minute
        management: { requests: 300, window: 3600 } # 300 requests per hour
      },
      "search_console" => {
        default: { requests: 1200, window: 86400 }, # 1,200 requests per day
        search_analytics: { requests: 200, window: 3600 }, # 200 requests per hour
        sites: { requests: 100, window: 3600 }, # 100 requests per hour
        sitemaps: { requests: 50, window: 3600 } # 50 requests per hour
      },
      # OAuth endpoints for Google
      "google_oauth" => {
        token: { requests: 100, window: 3600 }, # 100 token requests per hour
        refresh: { requests: 1000, window: 3600 }, # 1,000 refresh requests per hour
        revoke: { requests: 50, window: 3600 } # 50 revoke requests per hour
      },
      # Email Marketing Platforms
      "mailchimp" => {
        default: { requests: 10000, window: 86400 }, # 10,000 requests per day
        campaigns: { requests: 200, window: 3600 }, # 200 requests per hour
        lists: { requests: 300, window: 3600 }, # 300 requests per hour
        subscribers: { requests: 1000, window: 3600 }, # 1,000 requests per hour
        reports: { requests: 500, window: 3600 }, # 500 requests per hour
        automations: { requests: 100, window: 3600 }, # 100 requests per hour
        webhooks: { requests: 50, window: 3600 } # 50 requests per hour
      },
      "sendgrid" => {
        default: { requests: 1200, window: 3600 }, # 1,200 requests per hour
        campaigns: { requests: 600, window: 3600 }, # 600 requests per hour
        stats: { requests: 500, window: 3600 }, # 500 requests per hour
        contacts: { requests: 1000, window: 3600 }, # 1,000 requests per hour
        templates: { requests: 300, window: 3600 }, # 300 requests per hour
        webhooks: { requests: 100, window: 3600 } # 100 requests per hour
      },
      "constant_contact" => {
        default: { requests: 10000, window: 86400 }, # 10,000 requests per day
        campaigns: { requests: 400, window: 3600 }, # 400 requests per hour
        contacts: { requests: 800, window: 3600 }, # 800 requests per hour
        reports: { requests: 200, window: 3600 }, # 200 requests per hour
        lists: { requests: 300, window: 3600 }, # 300 requests per hour
        webhooks: { requests: 50, window: 3600 } # 50 requests per hour
      },
      "campaign_monitor" => {
        default: { requests: 1000, window: 3600 }, # 1,000 requests per hour
        campaigns: { requests: 200, window: 3600 }, # 200 requests per hour
        subscribers: { requests: 500, window: 3600 }, # 500 requests per hour
        reports: { requests: 300, window: 3600 }, # 300 requests per hour
        lists: { requests: 200, window: 3600 }, # 200 requests per hour
        webhooks: { requests: 50, window: 3600 } # 50 requests per hour
      },
      "activecampaign" => {
        default: { requests: 5000, window: 86400 }, # 5,000 requests per day
        campaigns: { requests: 300, window: 3600 }, # 300 requests per hour
        contacts: { requests: 500, window: 3600 }, # 500 requests per hour
        automations: { requests: 200, window: 3600 }, # 200 requests per hour
        reports: { requests: 150, window: 3600 }, # 150 requests per hour
        webhooks: { requests: 50, window: 3600 } # 50 requests per hour
      },
      "klaviyo" => {
        default: { requests: 75, window: 60 }, # 75 requests per minute
        profiles: { requests: 150, window: 3600 }, # 150 requests per hour
        campaigns: { requests: 100, window: 3600 }, # 100 requests per hour
        flows: { requests: 75, window: 3600 }, # 75 requests per hour
        metrics: { requests: 200, window: 3600 }, # 200 requests per hour
        webhooks: { requests: 25, window: 3600 } # 25 requests per hour
      },
      # CRM Platforms
      "salesforce" => {
        default: { requests: 15000, window: 86400 }, # 15,000 requests per day
        query: { requests: 20000, window: 86400 }, # 20,000 SOQL queries per day
        api: { requests: 1000, window: 3600 }, # 1,000 API calls per hour
        bulk: { requests: 10000, window: 86400 }, # 10,000 bulk API batches per day
        streaming: { requests: 40, window: 60 }, # 40 streaming API requests per minute
        oauth: { requests: 300, window: 3600 } # 300 OAuth requests per hour
      },
      "hubspot" => {
        default: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        contacts: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        deals: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        companies: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        search: { requests: 4, window: 1 }, # 4 search requests per second
        batch: { requests: 3, window: 1 }, # 3 batch requests per second
        oauth: { requests: 100, window: 3600 } # 100 OAuth requests per hour
      },
      "marketo" => {
        default: { requests: 100, window: 20 }, # 100 requests per 20 seconds
        bulk_extract: { requests: 2, window: 1 }, # 2 bulk extract jobs at once
        bulk_import: { requests: 10, window: 1 }, # 10 bulk import jobs at once
        identity: { requests: 50000, window: 86400 }, # 50,000 identity calls per day
        oauth: { requests: 100, window: 3600 } # 100 OAuth requests per hour
      },
      "pardot" => {
        default: { requests: 25000, window: 86400 }, # 25,000 requests per day
        api: { requests: 200, window: 3600 }, # 200 API calls per hour
        prospects: { requests: 1000, window: 3600 }, # 1,000 prospect calls per hour
        campaigns: { requests: 200, window: 3600 }, # 200 campaign calls per hour
        oauth: { requests: 300, window: 3600 } # 300 OAuth requests per hour (same as Salesforce)
      },
      "pipedrive" => {
        default: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        deals: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        persons: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        organizations: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        activities: { requests: 100, window: 10 }, # 100 requests per 10 seconds
        oauth: { requests: 100, window: 3600 } # 100 OAuth requests per hour
      },
      "zoho" => {
        default: { requests: 100, window: 60 }, # 100 requests per minute
        records: { requests: 200, window: 60 }, # 200 record operations per minute
        search: { requests: 20, window: 60 }, # 20 search requests per minute
        bulk: { requests: 25000, window: 86400 }, # 25,000 bulk operations per day
        oauth: { requests: 100, window: 3600 } # 100 OAuth requests per hour
      }
    }.freeze

    # Module methods that can be included in other services
    def with_rate_limiting(endpoint, user_id: nil, platform: nil, &block)
      return ServiceResult.failure("Block is required") unless block_given?

      platform ||= determine_platform_from_endpoint(endpoint)
      rate_limiter = RateLimiter.new(
        platform: platform,
        user_id: user_id,
        endpoint: endpoint
      )

      # Check if we can make the request
      unless rate_limiter.can_make_request?
        wait_time = rate_limiter.wait_time_until_reset
        return ServiceResult.failure(
          "Rate limit exceeded. Try again in #{wait_time} seconds.",
          data: { wait_time: wait_time, retry_after: wait_time }
        )
      end

      # Record the request
      rate_limiter.record_request

      # Execute the block with exponential backoff
      rate_limiter.execute_with_exponential_backoff(&block)
    end

    private

    def determine_platform_from_endpoint(endpoint)
      case endpoint
      when /google_ads/
        "google_ads"
      when /ga4|google_analytics/
        "google_analytics"
      when /search_console/
        "search_console"
      when /google_oauth/
        "google_oauth"
      when /facebook/
        "facebook"
      when /instagram/
        "instagram"
      when /linkedin/
        "linkedin"
      when /twitter/
        "twitter"
      when /tiktok/
        "tiktok"
      when /mailchimp/
        "mailchimp"
      when /sendgrid/
        "sendgrid"
      when /constant_contact/
        "constant_contact"
      when /campaign_monitor/
        "campaign_monitor"
      when /activecampaign/
        "activecampaign"
      when /klaviyo/
        "klaviyo"
      when /salesforce/
        "salesforce"
      when /hubspot/
        "hubspot"
      when /marketo/
        "marketo"
      when /pardot/
        "pardot"
      when /pipedrive/
        "pipedrive"
      when /zoho/
        "zoho"
      else
        "default"
      end
    end

    # Internal rate limiter class
    class RateLimiter
      include ActiveModel::Model
      include ActiveModel::Attributes

      attr_accessor :platform, :user_id, :endpoint, :integration_id

      def initialize(attributes = {})
        super
        @redis = Redis.new
        @endpoint ||= "default"
      end

    def can_make_request?
      rate_limit_key = build_rate_limit_key
      current_count = @redis.get(rate_limit_key).to_i
      limit = rate_limit_config[:requests]

      current_count < limit
    rescue Redis::CannotConnectError
      # If Redis is not available, allow requests to proceed
      Rails.logger.warn "Redis not available for rate limiting check"
      true
    end

    def record_request
      rate_limit_key = build_rate_limit_key
      window = rate_limit_config[:window]

      # Increment counter with expiration
      current_count = @redis.incr(rate_limit_key)

      # Set expiration only on first request
      @redis.expire(rate_limit_key, window) if current_count == 1

      # Check if we've hit the limit
      if current_count >= rate_limit_config[:requests]
        set_rate_limit_exceeded
      end

      current_count
    rescue Redis::CannotConnectError
      # If Redis is not available, return 1 to simulate first request
      Rails.logger.warn "Redis not available for recording request"
      1
    end

    def wait_time_until_reset
      rate_limit_key = build_rate_limit_key
      ttl = @redis.ttl(rate_limit_key)

      ttl > 0 ? ttl : 0
    rescue Redis::CannotConnectError
      Rails.logger.warn "Redis not available for checking rate limit reset time"
      0
    end

    def reset_rate_limit
      rate_limit_key = build_rate_limit_key
      @redis.del(rate_limit_key)

      # Also remove from integration record
      if integration_id
        integration = SocialMediaIntegration.find_by(id: integration_id)
        integration&.update(rate_limit_reset_at: nil)
      end
    rescue Redis::CannotConnectError
      Rails.logger.warn "Redis not available for resetting rate limit"
    end

    def execute_with_rate_limiting(&block)
      return ServiceResult.failure("Block is required") unless block_given?

      # Check if we can make the request
      unless can_make_request?
        wait_time = wait_time_until_reset
        return ServiceResult.failure(
          "Rate limit exceeded. Try again in #{wait_time} seconds.",
          data: { wait_time: wait_time, retry_after: wait_time }
        )
      end

      # Record the request
      record_request

      # Execute the block with exponential backoff on rate limit errors
      execute_with_exponential_backoff(&block)
    end

    def execute_with_exponential_backoff(max_retries: 3, base_delay: 1, &block)
      attempt = 0

      begin
        attempt += 1
        result = yield

        # Reset error count on successful request
        reset_integration_error_count if result.success?

        result
      rescue => e
        if rate_limit_error?(e) && attempt <= max_retries
          delay = calculate_backoff_delay(attempt, base_delay)
          Rails.logger.warn "Rate limit hit for #{platform}, retrying in #{delay} seconds (attempt #{attempt}/#{max_retries})"

          sleep(delay)
          retry
        else
          # Record error in integration
          increment_integration_error_count

          ServiceResult.failure(
            "Request failed after #{attempt} attempts: #{e.message}",
            data: { error_class: e.class.name, attempts: attempt }
          )
        end
      end
    end

    def self.check_all_integrations_rate_limits
      SocialMediaIntegration.active.find_each do |integration|
        service = new(
          platform: integration.platform,
          integration_id: integration.id
        )

        unless service.can_make_request?
          wait_time = service.wait_time_until_reset
          integration.update!(
            rate_limit_reset_at: wait_time.seconds.from_now
          )
        end
      end
    end

    def self.reset_expired_rate_limits
      expired_integrations = SocialMediaIntegration.where(
        "rate_limit_reset_at < ?", Time.current
      )

      expired_integrations.update_all(rate_limit_reset_at: nil)

      expired_integrations.each do |integration|
        service = new(
          platform: integration.platform,
          integration_id: integration.id
        )
        service.reset_rate_limit
      end
    end

    private

    def rate_limit_config
      RATE_LIMITS.dig(platform, endpoint) || RATE_LIMITS.dig(platform, "default") || { requests: 100, window: 3600 }
    end

    def build_rate_limit_key
      "rate_limit:#{platform}:#{integration_id || user_id || 'global'}:#{endpoint}"
    end

    def set_rate_limit_exceeded
      return unless integration_id

      integration = SocialMediaIntegration.find_by(id: integration_id)
      return unless integration

      reset_time = Time.current + rate_limit_config[:window].seconds
      integration.update!(rate_limit_reset_at: reset_time)
    end

    def calculate_backoff_delay(attempt, base_delay)
      # Exponential backoff with jitter
      delay = base_delay * (2 ** (attempt - 1))
      jitter = rand(0.1..0.3) * delay
      [ delay + jitter, 60 ].min # Cap at 60 seconds
    end

      def rate_limit_error?(error)
        case error
        when Faraday::TooManyRequestsError
          true
        when Faraday::ClientError
          error.response&.dig(:status) == 429
        when Google::Ads::GoogleAds::Errors::GoogleAdsError
          error.failure&.errors&.any? { |e| e.error_code&.name == "QUOTA_EXCEEDED" }
        when Google::Cloud::ResourceExhaustedError
          true
        when Google::Apis::RateLimitError
          true
        when Google::Apis::Error
          error.status_code == 429
        when StandardError
          error.message.match?(/rate limit|too many requests|quota exceeded|resource exhausted/i)
        else
          false
        end
      end

      def google_api_error?(error)
        error.is_a?(Google::Ads::GoogleAds::Errors::GoogleAdsError) ||
          error.is_a?(Google::Cloud::Error) ||
          error.is_a?(Google::Apis::Error)
      end

      def extract_retry_after(error)
        case error
        when Faraday::TooManyRequestsError, Faraday::ClientError
          error.response&.headers&.dig("Retry-After")&.to_i
        when Google::Ads::GoogleAds::Errors::GoogleAdsError
          # Google Ads API typically suggests waiting an hour for quota exceeded
          3600
        when Google::Cloud::ResourceExhaustedError
          # Google Cloud APIs typically reset quotas hourly
          3600
        when Google::Apis::Error
          if error.status_code == 429
            error.header&.dig("Retry-After")&.to_i || 3600
          end
        else
          nil
        end
      end

    def reset_integration_error_count
      return unless integration_id

      integration = SocialMediaIntegration.find_by(id: integration_id)
      integration&.reset_error_count!
    end

    def increment_integration_error_count
      return unless integration_id

      integration = SocialMediaIntegration.find_by(id: integration_id)
      integration&.increment_error_count!
    end
    end
  end
end
