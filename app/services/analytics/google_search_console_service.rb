# frozen_string_literal: true

require "google/apis/webmasters_v3"

module Analytics
  # Google Search Console API integration service for SEO analytics,
  # keyword rankings, search performance metrics, and website indexing status
  class GoogleSearchConsoleService
    include Analytics::RateLimitingService

    SUPPORTED_DIMENSIONS = %w[
      query page country device date
    ].freeze

    SUPPORTED_METRICS = %w[
      clicks impressions ctr position
    ].freeze

    SEARCH_TYPES = %w[web image video].freeze

    class SearchConsoleApiError < StandardError
      attr_reader :error_code, :error_type, :retry_after

      def initialize(message, error_code: nil, error_type: nil, retry_after: nil)
        super(message)
        @error_code = error_code
        @error_type = error_type
        @retry_after = retry_after
      end
    end

    def initialize(user_id:, site_url: nil)
      @user_id = user_id
      @site_url = site_url
      @oauth_service = GoogleOauthService.new(user_id: user_id, integration_type: :search_console)
      @service = build_search_console_service
    end

    # Get all verified sites/properties in Search Console
    def verified_sites
      with_rate_limiting("search_console_sites", user_id: @user_id) do
        sites_list = @service.list_sites

        verified_sites = sites_list.site_entry.select do |site|
          site.permission_level == "siteOwner" || site.permission_level == "siteFullUser"
        end

        sites_data = verified_sites.map do |site|
          {
            site_url: site.site_url,
            permission_level: site.permission_level,
            verified: true
          }
        end

        cache_verified_sites(sites_data)
        sites_data
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch verified sites")
    end

    # Get search analytics data for keywords and queries
    def search_analytics(start_date:, end_date:, dimensions: %w[query], search_type: "web", row_limit: 1000)
      validate_date_range!(start_date, end_date)
      validate_dimensions!(dimensions)
      validate_search_type!(search_type)

      with_rate_limiting("search_console_analytics", user_id: @user_id) do
        request = Google::Apis::WebmastersV3::SearchAnalyticsQueryRequest.new(
          start_date: start_date,
          end_date: end_date,
          dimensions: dimensions,
          search_type: search_type,
          row_limit: row_limit,
          start_row: 0
        )

        response = @service.query_search_analytics(@site_url, request)

        {
          site_url: @site_url,
          date_range: { start_date: start_date, end_date: end_date },
          search_type: search_type,
          dimensions: dimensions,
          data: extract_search_analytics_data(response),
          summary: calculate_search_summary(response),
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch search analytics")
    end

    # Get keyword performance and rankings
    def keyword_rankings(start_date:, end_date:, queries: [], country: nil, device: nil)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("search_console_keywords", user_id: @user_id) do
        dimensions = %w[query page]
        dimensions << "country" if country
        dimensions << "device" if device

        request = Google::Apis::WebmastersV3::SearchAnalyticsQueryRequest.new(
          start_date: start_date,
          end_date: end_date,
          dimensions: dimensions,
          search_type: "web",
          row_limit: 10_000,
          start_row: 0
        )

        # Add query filter if specific keywords provided
        if queries.any?
          request.dimension_filter_groups = [
            Google::Apis::WebmastersV3::ApiDimensionFilterGroup.new(
              filters: [
                Google::Apis::WebmastersV3::ApiDimensionFilter.new(
                  dimension: "query",
                  operator: "contains",
                  expression: queries.join("|")
                )
              ]
            )
          ]
        end

        response = @service.query_search_analytics(@site_url, request)

        rankings = extract_keyword_rankings(response)

        {
          site_url: @site_url,
          date_range: { start_date: start_date, end_date: end_date },
          keyword_rankings: rankings,
          top_keywords: extract_top_keywords(rankings),
          ranking_distribution: calculate_ranking_distribution(rankings),
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch keyword rankings")
    end

    # Get page performance metrics
    def page_performance(start_date:, end_date:, pages: [], country: nil)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("search_console_pages", user_id: @user_id) do
        dimensions = %w[page query]
        dimensions << "country" if country

        request = Google::Apis::WebmastersV3::SearchAnalyticsQueryRequest.new(
          start_date: start_date,
          end_date: end_date,
          dimensions: dimensions,
          search_type: "web",
          row_limit: 5000,
          start_row: 0
        )

        # Add page filter if specific pages provided
        if pages.any?
          request.dimension_filter_groups = [
            Google::Apis::WebmastersV3::ApiDimensionFilterGroup.new(
              filters: [
                Google::Apis::WebmastersV3::ApiDimensionFilter.new(
                  dimension: "page",
                  operator: "contains",
                  expression: pages.join("|")
                )
              ]
            )
          ]
        end

        response = @service.query_search_analytics(@site_url, request)

        page_data = extract_page_performance_data(response)

        {
          site_url: @site_url,
          date_range: { start_date: start_date, end_date: end_date },
          page_performance: page_data,
          top_pages: extract_top_pages(page_data),
          performance_insights: analyze_page_performance(page_data),
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch page performance")
    end

    # Get search appearance data (Rich Results, AMP, etc.)
    def search_appearance(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("search_console_appearance", user_id: @user_id) do
        appearance_data = {}

        # Get different search appearance types
        %w[web image video].each do |search_type|
          request = Google::Apis::WebmastersV3::SearchAnalyticsQueryRequest.new(
            start_date: start_date,
            end_date: end_date,
            dimensions: %w[page],
            search_type: search_type,
            row_limit: 1000,
            start_row: 0
          )

          response = @service.query_search_analytics(@site_url, request)
          appearance_data[search_type] = extract_appearance_data(response, search_type)
        end

        {
          site_url: @site_url,
          date_range: { start_date: start_date, end_date: end_date },
          search_appearance: appearance_data,
          rich_results_summary: summarize_rich_results(appearance_data),
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch search appearance data")
    end

    # Get indexing status and coverage issues
    def indexing_status
      with_rate_limiting("search_console_indexing", user_id: @user_id) do
        # Note: The indexing API requires different endpoints
        # This is a simplified version focusing on sitemap status
        sitemaps_response = @service.list_sitemaps(@site_url)

        sitemaps_data = sitemaps_response.sitemap.map do |sitemap|
          {
            path: sitemap.path,
            last_submitted: sitemap.last_submitted,
            is_pending: sitemap.is_pending,
            is_sitemaps_index: sitemap.is_sitemaps_index,
            type: sitemap.type,
            last_downloaded: sitemap.last_downloaded,
            warnings: sitemap.warnings,
            errors: sitemap.errors
          }
        end

        {
          site_url: @site_url,
          sitemaps: sitemaps_data,
          sitemap_summary: summarize_sitemap_status(sitemaps_data),
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch indexing status")
    end

    # Get mobile usability issues
    def mobile_usability_issues
      with_rate_limiting("search_console_mobile", user_id: @user_id) do
        # Note: Mobile usability API might not be available in all versions
        # This is a placeholder for the expected functionality
        {
          site_url: @site_url,
          mobile_usability: {
            mobile_friendly_pages: 0,
            mobile_issues: [],
            last_crawled: Time.current
          },
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch mobile usability data")
    end

    # Get Core Web Vitals data
    def core_web_vitals(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("search_console_vitals", user_id: @user_id) do
        # Note: Core Web Vitals data might require different API endpoints
        # This provides a structure for when the API becomes available
        {
          site_url: @site_url,
          date_range: { start_date: start_date, end_date: end_date },
          core_web_vitals: {
            largest_contentful_paint: {
              good: 0,
              needs_improvement: 0,
              poor: 0
            },
            first_input_delay: {
              good: 0,
              needs_improvement: 0,
              poor: 0
            },
            cumulative_layout_shift: {
              good: 0,
              needs_improvement: 0,
              poor: 0
            }
          },
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to fetch Core Web Vitals data")
    end

    # Submit sitemap for indexing
    def submit_sitemap(sitemap_url)
      with_rate_limiting("search_console_sitemap_submit", user_id: @user_id) do
        @service.submit_sitemap(@site_url, sitemap_url)

        {
          site_url: @site_url,
          sitemap_url: sitemap_url,
          submitted_at: Time.current,
          status: "submitted"
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to submit sitemap")
    end

    # Get comprehensive SEO performance report
    def seo_performance_report(start_date:, end_date:)
      validate_date_range!(start_date, end_date)

      with_rate_limiting("search_console_seo_report", user_id: @user_id) do
        # Gather multiple data points for comprehensive report
        search_data = search_analytics(
          start_date: start_date,
          end_date: end_date,
          dimensions: %w[query page country device]
        )

        keyword_data = keyword_rankings(
          start_date: start_date,
          end_date: end_date
        )

        page_data = page_performance(
          start_date: start_date,
          end_date: end_date
        )

        indexing_data = indexing_status

        {
          site_url: @site_url,
          date_range: { start_date: start_date, end_date: end_date },
          search_performance: search_data[:summary],
          top_keywords: keyword_data[:top_keywords],
          top_pages: page_data[:top_pages],
          indexing_status: indexing_data[:sitemap_summary],
          seo_insights: generate_seo_insights(search_data, keyword_data, page_data),
          recommendations: generate_seo_recommendations(search_data, keyword_data, page_data),
          generated_at: Time.current
        }
      end
    rescue Google::Apis::Error => e
      handle_search_console_error(e, "Failed to generate SEO performance report")
    end

    private

    attr_reader :user_id, :site_url, :oauth_service, :service

    def build_search_console_service
      service = Google::Apis::WebmastersV3::WebmastersService.new
      service.authorization = build_authorization
      service
    end

    def build_authorization
      token = @oauth_service.access_token
      raise SearchConsoleApiError.new("No valid access token", error_type: :auth_error) unless token

      Google::Auth::UserRefreshCredentials.new(
        client_id: google_client_id,
        client_secret: google_client_secret,
        refresh_token: token,
        scope: [ "https://www.googleapis.com/auth/webmasters.readonly" ]
      )
    end

    def extract_search_analytics_data(response)
      return [] unless response.rows

      response.rows.map do |row|
        row_data = {}

        # Map dimensions
        row.keys&.each_with_index do |key, index|
          case index
          when 0 then row_data[:query] = key if response.response_aggregation_type == "byQuery"
          when 1 then row_data[:page] = key if response.response_aggregation_type == "byPage"
          end
        end

        # Add metrics
        row_data.merge!(
          clicks: row.clicks,
          impressions: row.impressions,
          ctr: row.ctr,
          position: row.position
        )
      end
    end

    def calculate_search_summary(response)
      return {} unless response.rows

      total_clicks = response.rows.sum(&:clicks)
      total_impressions = response.rows.sum(&:impressions)
      average_ctr = total_impressions > 0 ? (total_clicks.to_f / total_impressions) : 0
      average_position = response.rows.sum(&:position) / response.rows.count.to_f

      {
        total_clicks: total_clicks,
        total_impressions: total_impressions,
        average_ctr: average_ctr.round(4),
        average_position: average_position.round(2),
        total_queries: response.rows.count
      }
    end

    def extract_keyword_rankings(response)
      return [] unless response.rows

      response.rows.map do |row|
        {
          query: row.keys&.first,
          page: row.keys&.second,
          clicks: row.clicks,
          impressions: row.impressions,
          ctr: row.ctr,
          position: row.position,
          ranking_tier: classify_ranking_tier(row.position)
        }
      end
    end

    def extract_top_keywords(rankings)
      rankings.sort_by { |k| -k[:impressions] }
              .first(20)
              .map do |keyword|
                {
                  query: keyword[:query],
                  impressions: keyword[:impressions],
                  clicks: keyword[:clicks],
                  position: keyword[:position],
                  ctr: keyword[:ctr]
                }
              end
    end

    def calculate_ranking_distribution(rankings)
      distribution = {
        "1-3" => 0,    # Top 3 positions
        "4-10" => 0,   # First page
        "11-20" => 0,  # Second page
        "21-50" => 0,  # Third to fifth page
        "51+" => 0     # Beyond fifth page
      }

      rankings.each do |ranking|
        position = ranking[:position]
        case position
        when 1..3
          distribution["1-3"] += 1
        when 4..10
          distribution["4-10"] += 1
        when 11..20
          distribution["11-20"] += 1
        when 21..50
          distribution["21-50"] += 1
        else
          distribution["51+"] += 1
        end
      end

      distribution
    end

    def extract_page_performance_data(response)
      return [] unless response.rows

      # Group by page to aggregate metrics
      page_groups = response.rows.group_by { |row| row.keys&.first }

      page_groups.map do |page, rows|
        total_clicks = rows.sum(&:clicks)
        total_impressions = rows.sum(&:impressions)
        average_position = rows.sum(&:position) / rows.count.to_f
        average_ctr = total_impressions > 0 ? (total_clicks.to_f / total_impressions) : 0

        {
          page: page,
          clicks: total_clicks,
          impressions: total_impressions,
          ctr: average_ctr.round(4),
          position: average_position.round(2),
          query_count: rows.count,
          top_queries: rows.sort_by(&:impressions).reverse.first(5).map { |r| r.keys&.second }
        }
      end
    end

    def extract_top_pages(page_data)
      page_data.sort_by { |p| -p[:impressions] }
               .first(20)
               .map do |page|
                 {
                   page: page[:page],
                   impressions: page[:impressions],
                   clicks: page[:clicks],
                   position: page[:position],
                   ctr: page[:ctr]
                 }
               end
    end

    def analyze_page_performance(page_data)
      high_impression_pages = page_data.select { |p| p[:impressions] > 1000 }
      low_ctr_pages = page_data.select { |p| p[:ctr] < 0.02 && p[:impressions] > 100 }
      high_position_pages = page_data.select { |p| p[:position] > 20 && p[:impressions] > 50 }

      {
        high_traffic_pages: high_impression_pages.count,
        low_ctr_opportunities: low_ctr_pages.count,
        ranking_improvement_opportunities: high_position_pages.count,
        average_page_position: page_data.sum { |p| p[:position] } / page_data.count.to_f
      }
    end

    def classify_ranking_tier(position)
      case position
      when 1..3
        "top_3"
      when 4..10
        "first_page"
      when 11..20
        "second_page"
      when 21..50
        "pages_3_5"
      else
        "beyond_page_5"
      end
    end

    def generate_seo_insights(search_data, keyword_data, page_data)
      {
        keyword_opportunities: identify_keyword_opportunities(keyword_data),
        content_gaps: identify_content_gaps(search_data, page_data),
        ranking_improvements: identify_ranking_improvements(keyword_data),
        technical_issues: identify_technical_issues(page_data)
      }
    end

    def generate_seo_recommendations(search_data, keyword_data, page_data)
      recommendations = []

      # CTR improvement recommendations
      low_ctr_keywords = keyword_data[:keyword_rankings].select { |k| k[:ctr] < 0.02 && k[:impressions] > 100 }
      if low_ctr_keywords.any?
        recommendations << {
          type: "ctr_optimization",
          priority: "high",
          description: "Optimize title tags and meta descriptions for #{low_ctr_keywords.count} high-impression, low-CTR keywords"
        }
      end

      # Position improvement recommendations
      page_2_keywords = keyword_data[:keyword_rankings].select { |k| k[:position].between?(11, 20) && k[:impressions] > 50 }
      if page_2_keywords.any?
        recommendations << {
          type: "ranking_improvement",
          priority: "medium",
          description: "Focus on improving #{page_2_keywords.count} keywords ranking on page 2 to reach first page"
        }
      end

      recommendations
    end

    def identify_keyword_opportunities(keyword_data)
      keyword_data[:keyword_rankings].select do |keyword|
        keyword[:position] > 10 && keyword[:impressions] > 100
      end.first(10)
    end

    def validate_date_range!(start_date, end_date)
      start_date_obj = Date.parse(start_date)
      end_date_obj = Date.parse(end_date)

      raise ArgumentError, "Start date must be before end date" if start_date_obj > end_date_obj
      raise ArgumentError, "Date range cannot exceed 90 days" if (end_date_obj - start_date_obj).to_i > 90
      raise ArgumentError, "End date cannot be more recent than 3 days ago" if end_date_obj > 3.days.ago.to_date
    rescue Date::Error
      raise ArgumentError, "Invalid date format. Use YYYY-MM-DD"
    end

    def validate_dimensions!(dimensions)
      invalid_dimensions = dimensions - SUPPORTED_DIMENSIONS
      return if invalid_dimensions.empty?

      raise ArgumentError, "Unsupported dimensions: #{invalid_dimensions.join(', ')}"
    end

    def validate_search_type!(search_type)
      return if SEARCH_TYPES.include?(search_type)

      raise ArgumentError, "Unsupported search type: #{search_type}. Use: #{SEARCH_TYPES.join(', ')}"
    end

    def cache_verified_sites(sites)
      cache_key = "search_console_sites:#{@user_id}"
      Rails.cache.write(cache_key, sites, expires_in: 1.hour)
    end

    def handle_search_console_error(error, context)
      Rails.logger.error "Google Search Console API Error - #{context}: #{error.message}"

      case error.status_code
      when 401
        @oauth_service.invalidate_stored_tokens
        raise SearchConsoleApiError.new(
          "Authentication failed. Please reconnect your Google Search Console account.",
          error_code: "UNAUTHENTICATED",
          error_type: :auth_error
        )
      when 403
        raise SearchConsoleApiError.new(
          "Access denied. Please ensure your account has proper Search Console permissions.",
          error_code: "PERMISSION_DENIED",
          error_type: :permission_error
        )
      when 429
        raise SearchConsoleApiError.new(
          "API quota exceeded. Please try again later.",
          error_code: "QUOTA_EXCEEDED",
          error_type: :rate_limit,
          retry_after: 3600
        )
      else
        raise SearchConsoleApiError.new(
          "Search Console API error: #{error.message}",
          error_code: error.status_code&.to_s,
          error_type: :api_error
        )
      end
    end

    def google_client_id
      Rails.application.credentials.dig(:google, :client_id) ||
        ENV["GOOGLE_CLIENT_ID"]
    end

    def google_client_secret
      Rails.application.credentials.dig(:google, :client_secret) ||
        ENV["GOOGLE_CLIENT_SECRET"]
    end
  end
end
