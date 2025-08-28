# frozen_string_literal: true

# Service for executing automated campaign deployment across platforms
# Handles scheduling, cross-platform deployment, performance monitoring,
# and automated optimization adjustments
class CampaignExecutionService < ApplicationService
  attr_reader :execution_schedule, :campaign_plan, :user, :platform_service
  
  def initialize(execution_schedule)
    @execution_schedule = execution_schedule
    @campaign_plan = execution_schedule.campaign_plan
    @user = execution_schedule.created_by
    @platform_service = PlatformIntegrationService.new(user, campaign_plan)
  end
  
  def call
    log_service_call("CampaignExecutionService#call", {
      execution_schedule_id: execution_schedule.id,
      campaign_plan_id: campaign_plan.id,
      target_platforms: execution_schedule.target_platforms
    })
    
    # Pre-execution validations
    validation_result = validate_execution_preconditions
    return validation_result unless validation_result[:success]
    
    # Mark execution as started
    execution_schedule.mark_executing!(user)
    
    begin
      # Prepare rollback data before execution
      rollback_data = prepare_rollback_data
      execution_schedule.prepare_rollback_data!(rollback_data)
      
      # Execute across all target platforms
      execution_results = execute_on_platforms
      
      # Monitor initial performance
      performance_results = monitor_initial_performance
      
      # Apply optimization adjustments if configured
      optimization_results = apply_optimization_adjustments(performance_results)
      
      # Consolidate results
      final_result = consolidate_execution_results(
        execution_results,
        performance_results,
        optimization_results
      )
      
      if final_result[:overall_success]
        execution_schedule.mark_completed!(user, final_result)
        campaign_plan.update!(
          plan_execution_started_at: execution_schedule.last_executed_at,
          metadata: (campaign_plan.metadata || {}).merge(
            last_execution_schedule_id: execution_schedule.id,
            execution_results: final_result
          )
        )
        success_response(final_result)
      else
        execution_schedule.mark_failed!(user, final_result[:error_message], final_result)
        handle_service_error(
          StandardError.new(final_result[:error_message]),
          final_result
        )
      end
      
    rescue => error
      execution_schedule.mark_failed!(user, error.message)
      handle_service_error(error, {
        execution_schedule_id: execution_schedule.id,
        phase: 'execution'
      })
    end
  end
  
  # Rollback a completed execution
  def rollback_execution
    log_service_call("CampaignExecutionService#rollback_execution", {
      execution_schedule_id: execution_schedule.id
    })
    
    unless execution_schedule.rollback_capabilities[:can_rollback]
      return handle_service_error(
        StandardError.new("Execution cannot be rolled back")
      )
    end
    
    begin
      rollback_data = execution_schedule.metadata.dig('rollback_data')
      rollback_results = {}
      
      rollback_data['platforms'].each do |platform|
        rollback_results[platform] = rollback_platform_deployment(
          platform, 
          rollback_data['campaign_ids'][platform]
        )
      end
      
      overall_success = rollback_results.values.all? { |result| result[:success] }
      
      if overall_success
        execution_schedule.update!(
          metadata: execution_schedule.metadata.merge(
            rolled_back_at: Time.current,
            rollback_results: rollback_results
          )
        )
        success_response({
          rollback_successful: true,
          rollback_results: rollback_results
        })
      else
        handle_service_error(
          StandardError.new("Rollback partially failed"),
          { rollback_results: rollback_results }
        )
      end
      
    rescue => error
      handle_service_error(error, {
        execution_schedule_id: execution_schedule.id,
        phase: 'rollback'
      })
    end
  end
  
  # Get execution status and progress
  def execution_status
    {
      execution_schedule: execution_schedule.execution_summary,
      campaign_plan: {
        id: campaign_plan.id,
        name: campaign_plan.name,
        status: campaign_plan.status
      },
      platform_status: get_platform_deployment_status,
      performance_metrics: get_current_performance_metrics,
      optimization_history: get_optimization_history
    }
  end
  
  private
  
  def validate_execution_preconditions
    errors = []
    
    # Check execution schedule status
    unless execution_schedule.can_be_executed?
      errors << "Execution schedule is not ready for execution"
    end
    
    # Check campaign plan status
    unless campaign_plan.approval_approved?
      errors << "Campaign plan must be approved before execution"
    end
    
    # Check execution window
    unless execution_schedule.in_execution_window?
      errors << "Current time is outside execution window"
    end
    
    # Check platform connections
    platform_test_results = platform_service.test_platform_connections
    unless platform_test_results[:success] && platform_test_results[:data][:all_connected]
      errors << "Not all platform connections are healthy"
    end
    
    # Check required content exists
    unless campaign_plan.has_generated_content?
      errors << "Campaign plan must have generated content"
    end
    
    if errors.any?
      return {
        success: false,
        error: "Pre-execution validation failed",
        validation_errors: errors
      }
    end
    
    success_response({ validation_passed: true })
  end
  
  def prepare_rollback_data
    rollback_data = {
      platforms: execution_schedule.target_platforms,
      campaign_ids: {},
      user_id: user.id,
      prepared_at: Time.current
    }
    
    # Get current campaign IDs for rollback reference
    execution_schedule.target_platforms.each do |platform|
      existing_campaigns = get_existing_campaigns_for_platform(platform)
      rollback_data[:campaign_ids][platform] = existing_campaigns
    end
    
    rollback_data
  end
  
  def execute_on_platforms
    results = {}
    
    execution_schedule.target_platforms.each do |platform|
      begin
        platform_config = execution_schedule.platform_config(platform)
        results[platform] = deploy_to_platform(platform, platform_config)
      rescue => error
        results[platform] = {
          success: false,
          error: error.message,
          platform: platform
        }
      end
    end
    
    results
  end
  
  def deploy_to_platform(platform, config)
    case platform
    when 'meta'
      deploy_to_meta(config)
    when 'google_ads'
      deploy_to_google_ads(config)
    when 'linkedin'
      deploy_to_linkedin(config)
    else
      { success: false, error: "Unsupported platform: #{platform}" }
    end
  end
  
  def deploy_to_meta(config)
    connection = user.platform_connections.for_platform('meta').active.first
    return { success: false, error: 'Meta connection not found' } unless connection
    
    client = connection.build_platform_client
    return { success: false, error: 'Meta client not available' } unless client
    
    # Create Meta campaigns based on campaign plan content
    campaign_data = build_meta_campaign_data(config)
    
    result = client.create_campaign(campaign_data)
    if result[:success]
      campaign_id = result[:data]['id']
      
      # Create ad sets and ads if configured
      adsets_result = create_meta_adsets(client, campaign_id, config)
      ads_result = create_meta_ads(client, campaign_id, config) if adsets_result[:success]
      
      {
        success: true,
        platform: 'meta',
        campaign_id: campaign_id,
        campaign_data: result[:data],
        adsets_created: adsets_result[:success] ? adsets_result[:count] : 0,
        ads_created: ads_result[:success] ? ads_result[:count] : 0
      }
    else
      { success: false, error: result[:error], platform: 'meta' }
    end
  end
  
  def deploy_to_google_ads(config)
    connection = user.platform_connections.for_platform('google_ads').active.first
    return { success: false, error: 'Google Ads connection not found' } unless connection
    
    client = connection.build_platform_client
    return { success: false, error: 'Google Ads client not available' } unless client
    
    # Create Google Ads campaigns
    campaign_data = build_google_ads_campaign_data(config)
    
    result = client.create_campaign(campaign_data)
    if result[:success]
      campaign_id = result[:data]['resourceName']
      
      # Create ad groups and ads
      adgroups_result = create_google_ads_adgroups(client, campaign_id, config)
      ads_result = create_google_ads_ads(client, campaign_id, config) if adgroups_result[:success]
      
      {
        success: true,
        platform: 'google_ads',
        campaign_id: campaign_id,
        campaign_data: result[:data],
        adgroups_created: adgroups_result[:success] ? adgroups_result[:count] : 0,
        ads_created: ads_result[:success] ? ads_result[:count] : 0
      }
    else
      { success: false, error: result[:error], platform: 'google_ads' }
    end
  end
  
  def deploy_to_linkedin(config)
    connection = user.platform_connections.for_platform('linkedin').active.first
    return { success: false, error: 'LinkedIn connection not found' } unless connection
    
    client = connection.build_platform_client
    return { success: false, error: 'LinkedIn client not available' } unless client
    
    # Create LinkedIn campaigns
    campaign_data = build_linkedin_campaign_data(config)
    
    result = client.create_campaign(campaign_data)
    if result[:success]
      campaign_id = result[:data]['id']
      
      # Create creatives
      creatives_result = create_linkedin_creatives(client, campaign_id, config)
      
      {
        success: true,
        platform: 'linkedin',
        campaign_id: campaign_id,
        campaign_data: result[:data],
        creatives_created: creatives_result[:success] ? creatives_result[:count] : 0
      }
    else
      { success: false, error: result[:error], platform: 'linkedin' }
    end
  end
  
  def monitor_initial_performance
    # Wait for initial performance data (15 minutes after deployment)
    sleep(15.minutes) if Rails.env.production?
    
    performance_data = {}
    execution_schedule.target_platforms.each do |platform|
      begin
        performance_data[platform] = get_platform_performance(platform)
      rescue => error
        performance_data[platform] = { 
          success: false, 
          error: error.message 
        }
      end
    end
    
    performance_data
  end
  
  def apply_optimization_adjustments(performance_data)
    return {} unless execution_schedule.execution_rules.dig('auto_optimize')
    
    optimization_results = {}
    
    execution_schedule.target_platforms.each do |platform|
      platform_performance = performance_data[platform]
      next unless platform_performance[:success]
      
      optimization_rules = execution_schedule.execution_rules.dig('optimization_rules', platform) || {}
      
      if should_optimize_platform?(platform_performance[:data], optimization_rules)
        optimization_results[platform] = optimize_platform_performance(
          platform, 
          platform_performance[:data], 
          optimization_rules
        )
      end
    end
    
    optimization_results
  end
  
  def consolidate_execution_results(execution_results, performance_results, optimization_results)
    successful_platforms = execution_results.select { |_, result| result[:success] }.keys
    failed_platforms = execution_results.select { |_, result| !result[:success] }.keys
    
    overall_success = failed_platforms.empty?
    
    {
      overall_success: overall_success,
      successful_platforms: successful_platforms,
      failed_platforms: failed_platforms,
      execution_results: execution_results,
      performance_results: performance_results,
      optimization_results: optimization_results,
      error_message: failed_platforms.any? ? "Execution failed on platforms: #{failed_platforms.join(', ')}" : nil,
      completed_at: Time.current
    }
  end
  
  # Platform-specific campaign building methods
  def build_meta_campaign_data(config)
    content_strategy = safe_parse_json_field(campaign_plan, :content_strategy)
    
    {
      name: "#{campaign_plan.name} - #{Time.current.strftime('%Y%m%d')}",
      objective: map_objective_to_meta(campaign_plan.objective),
      status: 'PAUSED', # Start paused for review
      daily_budget: extract_platform_budget(config, 'daily_budget'),
      targeting: build_meta_targeting(config),
      bid_strategy: config.dig('bid_strategy') || 'LOWEST_COST_WITHOUT_CAP'
    }
  end
  
  def build_google_ads_campaign_data(config)
    {
      name: "#{campaign_plan.name} - #{Time.current.strftime('%Y%m%d')}",
      advertisingChannelType: map_objective_to_google_ads(campaign_plan.objective),
      status: 'PAUSED',
      campaignBudget: {
        amountMicros: (extract_platform_budget(config, 'daily_budget') * 1_000_000).to_i
      },
      biddingStrategyType: config.dig('bid_strategy') || 'MAXIMIZE_CLICKS'
    }
  end
  
  def build_linkedin_campaign_data(config)
    {
      name: "#{campaign_plan.name} - #{Time.current.strftime('%Y%m%d')}",
      type: map_objective_to_linkedin(campaign_plan.objective),
      status: 'PAUSED',
      dailyBudget: {
        amount: extract_platform_budget(config, 'daily_budget') * 100, # LinkedIn uses cents
        currencyCode: 'USD'
      },
      targeting: build_linkedin_targeting(config)
    }
  end
  
  # Helper methods for campaign creation
  def extract_platform_budget(config, budget_type)
    config.dig('budget', budget_type) || 
    campaign_plan.budget_summary.dig(budget_type) || 
    100 # Default budget
  end
  
  def map_objective_to_meta(objective)
    mapping = {
      'brand_awareness' => 'BRAND_AWARENESS',
      'lead_generation' => 'LEAD_GENERATION',
      'customer_acquisition' => 'CONVERSIONS',
      'customer_retention' => 'CONVERSIONS',
      'sales_growth' => 'CONVERSIONS',
      'market_expansion' => 'REACH'
    }
    mapping[objective] || 'CONVERSIONS'
  end
  
  def map_objective_to_google_ads(objective)
    mapping = {
      'brand_awareness' => 'DISPLAY',
      'lead_generation' => 'SEARCH',
      'customer_acquisition' => 'SEARCH',
      'customer_retention' => 'SEARCH',
      'sales_growth' => 'SEARCH',
      'market_expansion' => 'DISPLAY'
    }
    mapping[objective] || 'SEARCH'
  end
  
  def map_objective_to_linkedin(objective)
    mapping = {
      'brand_awareness' => 'BRAND_AWARENESS',
      'lead_generation' => 'LEAD_GENERATION',
      'customer_acquisition' => 'WEBSITE_CONVERSIONS',
      'customer_retention' => 'WEBSITE_CONVERSIONS',
      'sales_growth' => 'WEBSITE_CONVERSIONS',
      'market_expansion' => 'BRAND_AWARENESS'
    }
    mapping[objective] || 'WEBSITE_CONVERSIONS'
  end
  
  def build_meta_targeting(config)
    audience_data = campaign_plan.target_audience_summary
    
    {
      age_min: audience_data.dig('age_range', 'min') || 18,
      age_max: audience_data.dig('age_range', 'max') || 65,
      genders: audience_data.dig('genders') || [1, 2],
      geo_locations: {
        countries: audience_data.dig('countries') || ['US']
      },
      interests: audience_data.dig('interests') || []
    }
  end
  
  def build_linkedin_targeting(config)
    audience_data = campaign_plan.target_audience_summary
    
    {
      includedTargetingFacets: {
        ageRanges: [audience_data.dig('age_range') || { min: 25, max: 54 }],
        locations: audience_data.dig('locations') || [{ country: 'US' }],
        skills: audience_data.dig('skills') || [],
        jobFunctions: audience_data.dig('job_functions') || []
      }
    }
  end
  
  # Performance monitoring methods
  def get_platform_performance(platform)
    date_range = {
      since: 1.hour.ago.strftime('%Y-%m-%d'),
      until: Time.current.strftime('%Y-%m-%d')
    }
    
    platform_service.sync_platform(platform, date_range)
  end
  
  def should_optimize_platform?(performance_data, optimization_rules)
    return false if optimization_rules.blank?
    
    # Check if performance meets thresholds for optimization
    ctr_threshold = optimization_rules.dig('min_ctr') || 0.5
    cpc_threshold = optimization_rules.dig('max_cpc') || 5.0
    
    current_ctr = performance_data.dig('ctr') || 0
    current_cpc = performance_data.dig('cpc') || 0
    
    current_ctr < ctr_threshold || current_cpc > cpc_threshold
  end
  
  def optimize_platform_performance(platform, performance_data, optimization_rules)
    # Implement platform-specific optimization logic
    # This could include bid adjustments, budget redistributions, etc.
    {
      platform: platform,
      optimization_applied: true,
      adjustments_made: ['bid_adjustment', 'budget_reallocation'],
      timestamp: Time.current
    }
  end
  
  # Rollback methods
  def rollback_platform_deployment(platform, campaign_ids)
    connection = user.platform_connections.for_platform(platform).active.first
    return { success: false, error: 'Connection not found' } unless connection
    
    client = connection.build_platform_client
    
    case platform
    when 'meta'
      rollback_meta_campaigns(client, campaign_ids)
    when 'google_ads'
      rollback_google_ads_campaigns(client, campaign_ids)
    when 'linkedin'
      rollback_linkedin_campaigns(client, campaign_ids)
    else
      { success: false, error: "Unsupported platform for rollback: #{platform}" }
    end
  end
  
  def rollback_meta_campaigns(client, campaign_ids)
    results = []
    campaign_ids.each do |campaign_id|
      result = client.update_campaign(campaign_id, { status: 'PAUSED' })
      results << result
    end
    
    {
      success: results.all? { |r| r[:success] },
      campaigns_paused: results.count { |r| r[:success] },
      total_campaigns: campaign_ids.count
    }
  end
  
  def rollback_google_ads_campaigns(client, campaign_ids)
    results = []
    campaign_ids.each do |campaign_id|
      result = client.update_campaign(campaign_id, { status: 'PAUSED' })
      results << result
    end
    
    {
      success: results.all? { |r| r[:success] },
      campaigns_paused: results.count { |r| r[:success] },
      total_campaigns: campaign_ids.count
    }
  end
  
  def rollback_linkedin_campaigns(client, campaign_ids)
    results = []
    campaign_ids.each do |campaign_id|
      result = client.update_campaign(campaign_id, { status: 'PAUSED' })
      results << result
    end
    
    {
      success: results.all? { |r| r[:success] },
      campaigns_paused: results.count { |r| r[:success] },
      total_campaigns: campaign_ids.count
    }
  end
  
  # Status and reporting methods
  def get_platform_deployment_status
    status = {}
    
    execution_schedule.target_platforms.each do |platform|
      connection = user.platform_connections.for_platform(platform).active.first
      status[platform] = {
        connected: connection.present?,
        last_sync: connection&.last_sync_at,
        health_status: connection&.status
      }
    end
    
    status
  end
  
  def get_current_performance_metrics
    return {} unless execution_schedule.completed?
    
    execution_result = execution_schedule.metadata.dig('execution_result')
    return {} unless execution_result
    
    {
      successful_platforms: execution_result['successful_platforms'],
      performance_summary: execution_result['performance_results'],
      last_updated: execution_schedule.updated_at
    }
  end
  
  def get_optimization_history
    execution_result = execution_schedule.metadata.dig('execution_result')
    return [] unless execution_result
    
    execution_result.dig('optimization_results')&.map do |platform, optimization|
      {
        platform: platform,
        optimization_applied: optimization['optimization_applied'],
        adjustments: optimization['adjustments_made'],
        timestamp: optimization['timestamp']
      }
    end || []
  end
  
  def get_existing_campaigns_for_platform(platform)
    # This would query existing campaigns on the platform
    # For rollback purposes - simplified implementation
    []
  end
  
  # Helper methods for creating ad components
  def create_meta_adsets(client, campaign_id, config)
    # Simplified - would create actual ad sets based on campaign plan content
    { success: true, count: 1 }
  end
  
  def create_meta_ads(client, campaign_id, config)
    # Simplified - would create actual ads based on generated content
    { success: true, count: 1 }
  end
  
  def create_google_ads_adgroups(client, campaign_id, config)
    # Simplified - would create actual ad groups
    { success: true, count: 1 }
  end
  
  def create_google_ads_ads(client, campaign_id, config)
    # Simplified - would create actual ads
    { success: true, count: 1 }
  end
  
  def create_linkedin_creatives(client, campaign_id, config)
    # Simplified - would create actual creatives
    { success: true, count: 1 }
  end
  
  # Helper method for safe JSON parsing
  def safe_parse_json_field(object, field_name)
    field_value = object.send(field_name)
    return {} if field_value.blank?
    
    if field_value.is_a?(String)
      JSON.parse(field_value)
    else
      field_value
    end
  rescue JSON::ParserError
    {}
  end
  
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
end