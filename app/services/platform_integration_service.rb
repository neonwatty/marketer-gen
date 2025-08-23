# frozen_string_literal: true

# Service for coordinating external platform integrations
# Manages authentication, data synchronization, and performance tracking
# across Meta, Google Ads, and LinkedIn platforms
class PlatformIntegrationService < ApplicationService
  SUPPORTED_PLATFORMS = %w[meta google_ads linkedin].freeze
  
  attr_reader :user, :campaign_plan, :platform_configs

  def initialize(user, campaign_plan = nil)
    @user = user
    @campaign_plan = campaign_plan
    @platform_configs = load_platform_configurations
  end

  # Synchronize performance data from all connected platforms
  def sync_all_platforms(date_range = {})
    log_service_call("PlatformIntegrationService#sync_all_platforms", {
      user_id: user.id,
      campaign_plan_id: campaign_plan&.id,
      date_range: date_range.except(:access_tokens)
    })

    results = {}
    errors = []

    SUPPORTED_PLATFORMS.each do |platform|
      begin
        client = get_platform_client(platform)
        next unless client

        results[platform] = sync_platform_data(platform, client, date_range)
      rescue => error
        Rails.logger.error "Platform sync failed for #{platform}: #{error.message}"
        errors << { platform: platform, error: error.message }
        results[platform] = { success: false, error: error.message }
      end
    end

    if errors.empty?
      update_campaign_performance_data(results) if campaign_plan
      success_response({
        platforms_synced: results.keys,
        sync_results: results,
        last_sync: Time.current
      })
    else
      handle_service_error(
        StandardError.new("Some platforms failed to sync: #{errors.map { |e| e[:platform] }.join(', ')}"),
        { errors: errors, partial_results: results }
      )
    end
  end

  # Sync data from a specific platform
  def sync_platform(platform_name, date_range = {})
    log_service_call("PlatformIntegrationService#sync_platform", {
      platform: platform_name,
      user_id: user.id,
      date_range: date_range.except(:access_tokens)
    })

    unless SUPPORTED_PLATFORMS.include?(platform_name)
      return handle_service_error(
        ArgumentError.new("Unsupported platform: #{platform_name}")
      )
    end

    begin
      client = get_platform_client(platform_name)
      return handle_service_error(
        StandardError.new("Platform client not available for #{platform_name}")
      ) unless client

      result = sync_platform_data(platform_name, client, date_range)
      
      if result[:success]
        update_single_platform_data(platform_name, result[:data]) if campaign_plan
        success_response(result)
      else
        handle_service_error(
          StandardError.new("Platform sync failed: #{result[:error]}"),
          result
        )
      end

    rescue => error
      handle_service_error(error, { platform: platform_name })
    end
  end

  # Test connectivity to all platforms
  def test_platform_connections
    log_service_call("PlatformIntegrationService#test_platform_connections", {
      user_id: user.id
    })

    results = {}

    SUPPORTED_PLATFORMS.each do |platform|
      begin
        client = get_platform_client(platform)
        if client
          health_check = client.health_check
          rate_limit = client.rate_limit_status
          
          results[platform] = {
            connected: true,
            health: health_check[:status],
            rate_limit: rate_limit,
            last_tested: Time.current
          }
        else
          results[platform] = {
            connected: false,
            error: 'No client configuration available',
            last_tested: Time.current
          }
        end
      rescue => error
        results[platform] = {
          connected: false,
          error: error.message,
          last_tested: Time.current
        }
      end
    end

    success_response({
      connection_tests: results,
      all_connected: results.values.all? { |r| r[:connected] }
    })
  end

  # Get aggregated performance metrics across platforms
  def get_aggregated_metrics(date_range = {})
    log_service_call("PlatformIntegrationService#get_aggregated_metrics", {
      user_id: user.id,
      campaign_plan_id: campaign_plan&.id,
      date_range: date_range.except(:access_tokens)
    })

    begin
      sync_result = sync_all_platforms(date_range)
      return sync_result unless sync_result[:success]

      platform_data = sync_result[:data][:sync_results]
      aggregated = aggregate_platform_metrics(platform_data)

      success_response({
        aggregated_metrics: aggregated,
        platform_breakdown: platform_data,
        date_range: format_date_range_summary(date_range),
        generated_at: Time.current
      })

    rescue => error
      handle_service_error(error)
    end
  end

  # Export performance data to various formats
  def export_performance_data(format = 'json', date_range = {})
    log_service_call("PlatformIntegrationService#export_performance_data", {
      format: format,
      user_id: user.id,
      date_range: date_range.except(:access_tokens)
    })

    begin
      metrics_result = get_aggregated_metrics(date_range)
      return metrics_result unless metrics_result[:success]

      export_data = prepare_export_data(metrics_result[:data])
      
      case format.downcase
      when 'csv'
        csv_content = generate_csv_export(export_data)
        success_response({ format: 'csv', content: csv_content, filename: csv_filename })
      when 'json'
        success_response({ format: 'json', content: export_data.to_json, filename: json_filename })
      else
        handle_service_error(ArgumentError.new("Unsupported export format: #{format}"))
      end

    rescue => error
      handle_service_error(error, { format: format })
    end
  end

  private

  # Helper method for logging service calls
  def log_service_call(service_name, params = {})
    Rails.logger.info "Service Call: #{service_name} with params: #{params.inspect}"
  end

  # Helper method for handling service errors
  def handle_service_error(error, context = {})
    Rails.logger.error "Service Error in #{self.class}: #{error.message}"
    Rails.logger.error "Context: #{context.inspect}" if context.any?
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Return a structured error response
    {
      success: false,
      error: error.message,
      context: context
    }
  end

  # Helper method for successful service responses
  def success_response(data = {})
    {
      success: true,
      data: data
    }
  end

  # Load platform configurations from user settings or environment
  def load_platform_configurations
    configs = {}
    
    # Try to load from user's stored credentials (implement as needed)
    # For now, return empty configs - this would be implemented based on 
    # how credentials are stored in the application
    
    SUPPORTED_PLATFORMS.each do |platform|
      configs[platform] = get_platform_config(platform)
    end
    
    configs
  end

  # Get platform-specific configuration from stored connections
  def get_platform_config(platform)
    connection = user.platform_connections.for_platform(platform).active.first
    return {} unless connection

    connection.credential_data
  end

  # Get appropriate platform client using stored connections
  def get_platform_client(platform)
    connection = user.platform_connections.for_platform(platform).active.first
    return nil unless connection

    connection.build_platform_client
  end

  # Sync data from a specific platform
  def sync_platform_data(platform, client, date_range)
    case platform
    when 'meta'
      sync_meta_data(client, date_range)
    when 'google_ads'
      sync_google_ads_data(client, date_range)
    when 'linkedin'
      sync_linkedin_data(client, date_range)
    else
      { success: false, error: "Unsupported platform: #{platform}" }
    end
  end

  # Sync Meta/Facebook data
  def sync_meta_data(client, date_range)
    data = {}
    
    # Get ad accounts
    accounts_response = client.get_ad_accounts
    return accounts_response unless accounts_response[:success]
    
    accounts = accounts_response[:data]['data'] || []
    data[:accounts] = accounts

    # Get campaign data for each account
    campaigns_data = []
    accounts.each do |account|
      account_id = account['id'].gsub('act_', '')
      campaigns_response = client.get_campaigns(account_id)
      
      if campaigns_response[:success]
        campaigns = campaigns_response[:data]['data'] || []
        
        campaigns.each do |campaign|
          performance = client.get_campaign_performance(campaign['id'], date_range)
          campaign['performance'] = performance[:data] if performance[:success]
        end
        
        campaigns_data += campaigns
      end
    end
    
    data[:campaigns] = campaigns_data
    
    { success: true, data: data }
  end

  # Sync Google Ads data
  def sync_google_ads_data(client, date_range)
    data = {}
    
    # Get customer info
    customer_response = client.get_customer_info
    return customer_response unless customer_response[:success]
    
    data[:customer] = customer_response[:data]
    
    # Get campaigns
    campaigns_response = client.get_campaigns
    return campaigns_response unless campaigns_response[:success]
    
    campaigns = campaigns_response[:data]['results'] || []
    data[:campaigns] = campaigns
    
    # Get performance data
    performance_response = client.get_campaign_performance(nil, nil, date_range)
    if performance_response[:success]
      data[:performance] = performance_response[:data]['results'] || []
    end
    
    { success: true, data: data }
  end

  # Sync LinkedIn data  
  def sync_linkedin_data(client, date_range)
    data = {}
    
    # Get profile info
    profile_response = client.get_profile
    return profile_response unless profile_response[:success]
    
    data[:profile] = profile_response[:data]
    
    # Get organizations
    orgs_response = client.get_organizations
    if orgs_response[:success]
      organizations = orgs_response[:data]['elements'] || []
      data[:organizations] = organizations
      
      # Get ad accounts and campaigns for each organization
      organizations.each do |org|
        org_id = org.dig('organization~', 'id')
        next unless org_id
        
        accounts_response = client.get_ad_accounts(org_id)
        if accounts_response[:success]
          accounts = accounts_response[:data]['elements'] || []
          
          accounts.each do |account|
            account_id = account['id']
            campaigns_response = client.get_campaigns(account_id)
            
            if campaigns_response[:success]
              campaigns = campaigns_response[:data]['elements'] || []
              
              campaigns.each do |campaign|
                analytics = client.get_campaign_analytics(campaign['id'], date_range)
                campaign['analytics'] = analytics[:data] if analytics[:success]
              end
              
              account['campaigns'] = campaigns
            end
          end
          
          org['ad_accounts'] = accounts
        end
      end
    end
    
    { success: true, data: data }
  end

  # Update campaign plan with aggregated platform data
  def update_campaign_performance_data(platform_results)
    return unless campaign_plan

    performance_data = campaign_plan.performance_data || {}
    
    platform_results.each do |platform, result|
      next unless result[:success]
      
      performance_data[platform] = {
        'last_sync' => Time.current,
        'data' => result[:data],
        'status' => 'synced'
      }
    end
    
    campaign_plan.update!(
      performance_data: performance_data,
      metadata: (campaign_plan.metadata || {}).merge(
        last_platform_sync: Time.current,
        synced_platforms: platform_results.keys
      )
    )
  end

  # Update campaign plan with single platform data
  def update_single_platform_data(platform, data)
    return unless campaign_plan

    performance_data = campaign_plan.performance_data || {}
    performance_data[platform] = {
      'last_sync' => Time.current,
      'data' => data,
      'status' => 'synced'
    }
    
    campaign_plan.update!(
      performance_data: performance_data,
      metadata: (campaign_plan.metadata || {}).merge(
        "last_#{platform}_sync" => Time.current
      )
    )
  end

  # Aggregate metrics across platforms
  def aggregate_platform_metrics(platform_data)
    totals = {
      impressions: 0,
      clicks: 0,
      spend: 0,
      conversions: 0,
      reach: 0
    }

    platform_breakdown = {}
    
    platform_data.each do |platform, result|
      next unless result[:success]
      
      platform_metrics = extract_platform_metrics(platform, result[:data])
      platform_breakdown[platform] = platform_metrics
      
      # Aggregate totals
      totals[:impressions] += platform_metrics[:impressions] || 0
      totals[:clicks] += platform_metrics[:clicks] || 0
      totals[:spend] += platform_metrics[:spend] || 0
      totals[:conversions] += platform_metrics[:conversions] || 0
      totals[:reach] += platform_metrics[:reach] || 0
    end

    # Calculate derived metrics
    totals[:ctr] = totals[:impressions] > 0 ? (totals[:clicks].to_f / totals[:impressions] * 100).round(2) : 0
    totals[:cpc] = totals[:clicks] > 0 ? (totals[:spend].to_f / totals[:clicks]).round(2) : 0
    totals[:conversion_rate] = totals[:clicks] > 0 ? (totals[:conversions].to_f / totals[:clicks] * 100).round(2) : 0

    {
      totals: totals,
      platform_breakdown: platform_breakdown
    }
  end

  # Extract standardized metrics from platform-specific data
  def extract_platform_metrics(platform, data)
    case platform
    when 'meta'
      extract_meta_metrics(data)
    when 'google_ads'
      extract_google_ads_metrics(data)
    when 'linkedin'
      extract_linkedin_metrics(data)
    else
      { impressions: 0, clicks: 0, spend: 0, conversions: 0, reach: 0 }
    end
  end

  def extract_meta_metrics(data)
    campaigns = data[:campaigns] || []
    metrics = { impressions: 0, clicks: 0, spend: 0, conversions: 0, reach: 0 }

    campaigns.each do |campaign|
      performance = campaign['performance']&.dig('data')
      next unless performance && performance.is_a?(Array)

      performance.each do |perf|
        metrics[:impressions] += perf['impressions'].to_i
        metrics[:clicks] += perf['clicks'].to_i
        metrics[:spend] += perf['spend'].to_f
        metrics[:conversions] += perf['conversions']&.sum { |c| c['value'].to_i } || 0
        metrics[:reach] += perf['reach'].to_i
      end
    end

    metrics
  end

  def extract_google_ads_metrics(data)
    performance = data[:performance] || []
    metrics = { impressions: 0, clicks: 0, spend: 0, conversions: 0, reach: 0 }

    performance.each do |perf|
      campaign = perf['campaign'] || {}
      metric_data = perf['metrics'] || {}
      
      metrics[:impressions] += metric_data['impressions'].to_i
      metrics[:clicks] += metric_data['clicks'].to_i
      metrics[:spend] += (metric_data['costMicros'].to_f / 1_000_000) # Convert from micros
      metrics[:conversions] += metric_data['conversions'].to_f
      # Google Ads doesn't have direct reach metric like Facebook
      metrics[:reach] += metric_data['impressions'].to_i # Use impressions as proxy
    end

    metrics
  end

  def extract_linkedin_metrics(data)
    organizations = data[:organizations] || []
    metrics = { impressions: 0, clicks: 0, spend: 0, conversions: 0, reach: 0 }

    organizations.each do |org|
      ad_accounts = org['ad_accounts'] || []
      
      ad_accounts.each do |account|
        campaigns = account['campaigns'] || []
        
        campaigns.each do |campaign|
          analytics = campaign['analytics']&.dig('elements')
          next unless analytics && analytics.is_a?(Array)

          analytics.each do |analytic|
            metrics[:impressions] += analytic['impressions'].to_i
            metrics[:clicks] += analytic['clicks'].to_i
            metrics[:spend] += analytic['costInUsd'].to_f
            metrics[:conversions] += (analytic['externalWebsiteConversions'].to_i + analytic['oneClickLeads'].to_i)
            # LinkedIn doesn't have direct reach, use impressions
            metrics[:reach] += analytic['impressions'].to_i
          end
        end
      end
    end

    metrics
  end

  # Prepare data for export
  def prepare_export_data(metrics_data)
    {
      summary: metrics_data[:aggregated_metrics][:totals],
      platform_breakdown: metrics_data[:aggregated_metrics][:platform_breakdown],
      date_range: metrics_data[:date_range],
      exported_at: metrics_data[:generated_at],
      campaign: campaign_plan ? {
        id: campaign_plan.id,
        name: campaign_plan.name,
        campaign_type: campaign_plan.campaign_type
      } : nil
    }
  end

  # Generate CSV export
  def generate_csv_export(data)
    require 'csv'
    
    CSV.generate do |csv|
      # Headers
      csv << ['Platform', 'Impressions', 'Clicks', 'Spend', 'Conversions', 'Reach', 'CTR (%)', 'CPC', 'Conversion Rate (%)']
      
      # Platform breakdown
      data[:platform_breakdown].each do |platform, metrics|
        ctr = metrics[:impressions] > 0 ? (metrics[:clicks].to_f / metrics[:impressions] * 100).round(2) : 0
        cpc = metrics[:clicks] > 0 ? (metrics[:spend].to_f / metrics[:clicks]).round(2) : 0
        conv_rate = metrics[:clicks] > 0 ? (metrics[:conversions].to_f / metrics[:clicks] * 100).round(2) : 0
        
        csv << [
          platform.titleize,
          metrics[:impressions],
          metrics[:clicks], 
          metrics[:spend],
          metrics[:conversions],
          metrics[:reach],
          ctr,
          cpc,
          conv_rate
        ]
      end
      
      # Total row
      totals = data[:summary]
      csv << [
        'TOTAL',
        totals[:impressions],
        totals[:clicks],
        totals[:spend],
        totals[:conversions],
        totals[:reach],
        totals[:ctr],
        totals[:cpc],
        totals[:conversion_rate]
      ]
    end
  end

  def csv_filename
    prefix = campaign_plan ? "campaign_#{campaign_plan.id}" : "platform_performance"
    "#{prefix}_#{Date.current.strftime('%Y%m%d')}.csv"
  end

  def json_filename
    prefix = campaign_plan ? "campaign_#{campaign_plan.id}" : "platform_performance"
    "#{prefix}_#{Date.current.strftime('%Y%m%d')}.json"
  end

  def format_date_range_summary(date_range)
    if date_range[:since] && date_range[:until]
      "#{date_range[:since]} to #{date_range[:until]}"
    else
      "Last 30 days"
    end
  end
end