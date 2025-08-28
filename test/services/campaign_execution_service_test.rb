# frozen_string_literal: true

require 'test_helper'

class CampaignExecutionServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Set up approved campaign plan for execution
    @campaign_plan.update!(
      approval_status: 'approved',
      status: 'completed',
      generated_summary: 'Test summary',
      generated_strategy: { 'key' => 'value' }.to_json,
      generated_timeline: { 'phases' => [{ 'name' => 'Phase 1', 'duration' => 14 }] }.to_json,
      generated_assets: { 'assets' => ['asset1', 'asset2'] }.to_json
    )
    
    @execution_schedule = ExecutionSchedule.create!(
      campaign_plan: @campaign_plan,
      name: "Test Execution",
      scheduled_at: 1.hour.from_now, # Future time for validation
      platform_targets: {
        "meta" => {
          "budget" => { "daily_budget" => 100 },
          "targeting" => { "age_range" => { "min" => 25, "max" => 54 } }
        }
      },
      execution_rules: {
        "start_hour" => 0,
        "end_hour" => 23,
        "timezone" => "UTC",
        "days_of_week" => [1, 2, 3, 4, 5, 6, 7], # All days to avoid window issues
        "auto_optimize" => true,
        "send_notifications" => false # Disable for testing
      },
      status: 'scheduled',
      priority: 5,
      created_by: @user,
      updated_by: @user
    )
    
    # Make the schedule executable by setting scheduled_at to past time
    @execution_schedule.update_column(:scheduled_at, 1.hour.ago)
    
    @service = CampaignExecutionService.new(@execution_schedule)
    
    # Mock platform connections
    setup_platform_connections
    setup_platform_service_mocks
  end

  # Basic initialization tests
  test "initializes with correct attributes" do
    assert_equal @execution_schedule, @service.execution_schedule
    assert_equal @campaign_plan, @service.campaign_plan
    assert_equal @user, @service.user
    assert_not_nil @service.platform_service
  end

  # Validation tests
  test "validate_execution_preconditions passes with valid setup" do
    result = @service.send(:validate_execution_preconditions)
    assert result[:success], "Validation should pass: #{result[:validation_errors]}"
  end

  test "validate_execution_preconditions fails when schedule cannot be executed" do
    @execution_schedule.update!(status: 'completed')
    result = @service.send(:validate_execution_preconditions)
    
    assert_not result[:success]
    assert_includes result[:validation_errors], "Execution schedule is not ready for execution"
  end

  test "validate_execution_preconditions fails when campaign not approved" do
    @campaign_plan.update!(approval_status: 'draft')
    result = @service.send(:validate_execution_preconditions)
    
    assert_not result[:success]
    assert_includes result[:validation_errors], "Campaign plan must be approved before execution"
  end

  test "validate_execution_preconditions fails when outside execution window" do
    @execution_schedule.update!(
      execution_rules: {
        "start_hour" => 1,
        "end_hour" => 2,
        "timezone" => "UTC",
        "days_of_week" => [1] # Only Monday
      }
    )
    
    # Mock current time to be outside window
    Time.stub :current, Time.zone.parse("2024-01-06 10:00:00 UTC") do # Saturday
      result = @service.send(:validate_execution_preconditions)
      assert_not result[:success]
      assert_includes result[:validation_errors], "Current time is outside execution window"
    end
  end

  test "validate_execution_preconditions fails when no generated content" do
    @campaign_plan.update!(
      generated_summary: nil,
      generated_strategy: nil,
      generated_timeline: nil,
      generated_assets: nil
    )
    
    result = @service.send(:validate_execution_preconditions)
    assert_not result[:success]
    assert_includes result[:validation_errors], "Campaign plan must have generated content"
  end

  # Platform deployment tests
  test "deploy_to_platform handles meta deployment" do
    config = { "budget" => { "daily_budget" => 100 } }
    
    # Mock successful Meta deployment directly at the service level
    expected_result = {
      success: true,
      platform: 'meta',
      campaign_id: 'campaign_123',
      campaign_data: { 'id' => 'campaign_123' },
      adsets_created: 1,
      ads_created: 1
    }
    
    @service.stub(:deploy_to_meta, expected_result) do
      result = @service.send(:deploy_to_platform, 'meta', config)
      assert result[:success]
      assert_equal 'meta', result[:platform]
      assert_equal 'campaign_123', result[:campaign_id]
    end
  end

  test "deploy_to_platform handles google_ads deployment" do
    config = { "budget" => { "daily_budget" => 150 } }
    
    # Mock successful Google Ads deployment directly at the service level
    expected_result = {
      success: true,
      platform: 'google_ads',
      campaign_id: 'customers/123/campaigns/456',
      campaign_data: { 'resourceName' => 'customers/123/campaigns/456' },
      adgroups_created: 1,
      ads_created: 1
    }
    
    @service.stub(:deploy_to_google_ads, expected_result) do
      result = @service.send(:deploy_to_platform, 'google_ads', config)
      assert result[:success]
      assert_equal 'google_ads', result[:platform]
      assert_equal 'customers/123/campaigns/456', result[:campaign_id]
    end
  end

  test "deploy_to_platform handles linkedin deployment" do
    config = { "budget" => { "daily_budget" => 200 } }
    
    # Mock successful LinkedIn deployment directly at the service level
    expected_result = {
      success: true,
      platform: 'linkedin',
      campaign_id: 'linkedin_campaign_789',
      campaign_data: { 'id' => 'linkedin_campaign_789' },
      creatives_created: 1
    }
    
    @service.stub(:deploy_to_linkedin, expected_result) do
      result = @service.send(:deploy_to_platform, 'linkedin', config)
      assert result[:success]
      assert_equal 'linkedin', result[:platform]
      assert_equal 'linkedin_campaign_789', result[:campaign_id]
    end
  end

  test "deploy_to_platform fails when platform connection missing" do
    @user.platform_connections.for_platform('meta').destroy_all
    config = { "budget" => { "daily_budget" => 100 } }
    
    result = @service.send(:deploy_to_platform, 'meta', config)
    assert_not result[:success]
    assert_equal 'Meta connection not found', result[:error]
  end

  test "deploy_to_platform handles unsupported platform" do
    config = {}
    result = @service.send(:deploy_to_platform, 'unsupported_platform', config)
    
    assert_not result[:success]
    assert_equal 'Unsupported platform: unsupported_platform', result[:error]
  end

  # Campaign data building tests
  test "build_meta_campaign_data creates correct structure" do
    config = {
      "budget" => { "daily_budget" => 100 },
      "bid_strategy" => "LOWEST_COST_WITH_CAP"
    }
    
    campaign_data = @service.send(:build_meta_campaign_data, config)
    
    assert_includes campaign_data[:name], @campaign_plan.name
    assert_equal 'PAUSED', campaign_data[:status]
    assert_equal 100, campaign_data[:daily_budget]
    assert_equal 'LOWEST_COST_WITH_CAP', campaign_data[:bid_strategy]
    assert campaign_data[:targeting].present?
  end

  test "build_google_ads_campaign_data creates correct structure" do
    config = {
      "budget" => { "daily_budget" => 150 },
      "bid_strategy" => "MAXIMIZE_CONVERSIONS"
    }
    
    campaign_data = @service.send(:build_google_ads_campaign_data, config)
    
    assert_includes campaign_data[:name], @campaign_plan.name
    assert_equal 'PAUSED', campaign_data[:status]
    assert_equal 150_000_000, campaign_data[:campaignBudget][:amountMicros] # 150 * 1M micros
    assert_equal 'MAXIMIZE_CONVERSIONS', campaign_data[:biddingStrategyType]
  end

  test "build_linkedin_campaign_data creates correct structure" do
    config = { "budget" => { "daily_budget" => 200 } }
    
    campaign_data = @service.send(:build_linkedin_campaign_data, config)
    
    assert_includes campaign_data[:name], @campaign_plan.name
    assert_equal 'PAUSED', campaign_data[:status]
    assert_equal 20000, campaign_data[:dailyBudget][:amount] # 200 * 100 cents
    assert_equal 'USD', campaign_data[:dailyBudget][:currencyCode]
  end

  # Objective mapping tests
  test "map_objective_to_meta maps correctly" do
    assert_equal 'BRAND_AWARENESS', @service.send(:map_objective_to_meta, 'brand_awareness')
    assert_equal 'LEAD_GENERATION', @service.send(:map_objective_to_meta, 'lead_generation')
    assert_equal 'CONVERSIONS', @service.send(:map_objective_to_meta, 'customer_acquisition')
    assert_equal 'CONVERSIONS', @service.send(:map_objective_to_meta, 'unknown_objective')
  end

  test "map_objective_to_google_ads maps correctly" do
    assert_equal 'DISPLAY', @service.send(:map_objective_to_google_ads, 'brand_awareness')
    assert_equal 'SEARCH', @service.send(:map_objective_to_google_ads, 'lead_generation')
    assert_equal 'SEARCH', @service.send(:map_objective_to_google_ads, 'unknown_objective')
  end

  test "map_objective_to_linkedin maps correctly" do
    assert_equal 'BRAND_AWARENESS', @service.send(:map_objective_to_linkedin, 'brand_awareness')
    assert_equal 'LEAD_GENERATION', @service.send(:map_objective_to_linkedin, 'lead_generation')
    assert_equal 'WEBSITE_CONVERSIONS', @service.send(:map_objective_to_linkedin, 'customer_acquisition')
  end

  # Targeting building tests
  test "build_meta_targeting creates correct structure" do
    @campaign_plan.update!(
      target_audience: {
        "age_range" => { "min" => 30, "max" => 50 },
        "genders" => [1],
        "countries" => ["US", "CA"],
        "interests" => ["marketing", "advertising"]
      }.to_json
    )
    
    config = {}
    targeting = @service.send(:build_meta_targeting, config)
    
    assert_equal 30, targeting[:age_min]
    assert_equal 50, targeting[:age_max]
    assert_equal [1], targeting[:genders]
    assert_equal ["US", "CA"], targeting[:geo_locations][:countries]
    assert_equal ["marketing", "advertising"], targeting[:interests]
  end

  test "build_linkedin_targeting creates correct structure" do
    @campaign_plan.update!(
      target_audience: {
        "age_range" => { "min" => 25, "max" => 45 },
        "locations" => [{ "country" => "US" }, { "country" => "CA" }],
        "skills" => ["Digital Marketing"],
        "job_functions" => ["Marketing"]
      }.to_json
    )
    
    config = {}
    targeting = @service.send(:build_linkedin_targeting, config)
    
    assert_equal [{"min" => 25, "max" => 45}], targeting[:includedTargetingFacets][:ageRanges]
    assert_equal [{ "country" => "US" }, { "country" => "CA" }], targeting[:includedTargetingFacets][:locations]
    assert_equal ["Digital Marketing"], targeting[:includedTargetingFacets][:skills]
    assert_equal ["Marketing"], targeting[:includedTargetingFacets][:jobFunctions]
  end

  # Full execution tests
  test "successful execution updates schedule and campaign plan" do
    # Mock successful platform execution at the service method level
    successful_execution_results = {
      'meta' => {
        success: true,
        platform: 'meta',
        campaign_id: 'campaign_123',
        campaign_data: { 'id' => 'campaign_123' }
      }
    }
    
    @service.stub(:execute_on_platforms, successful_execution_results) do
      @service.stub(:monitor_initial_performance, { success: true, data: {} }) do
        @service.stub(:apply_optimization_adjustments, { success: true, data: {} }) do
          result = @service.call
          assert result[:success], "Execution should succeed: #{result[:error]}"
        end
      end
    end
    
    @execution_schedule.reload
    assert @execution_schedule.completed?
    assert @execution_schedule.last_executed_at.present?
    
    @campaign_plan.reload
    assert @campaign_plan.plan_execution_started_at.present?
    assert_equal @execution_schedule.id, @campaign_plan.metadata['last_execution_schedule_id']
  end

  test "failed execution marks schedule as failed" do
    # Mock failed platform deployment
    mock_failed_deployment
    
    result = @service.call
    assert_not result[:success]
    
    @execution_schedule.reload
    assert @execution_schedule.failed?
  end

  # Rollback tests
  test "rollback_execution succeeds with valid rollback data" do
    # Set up completed execution with rollback data
    @execution_schedule.update!(
      status: 'completed',
      metadata: {
        'rollback_data' => {
          'platforms' => ['meta'],
          'campaign_ids' => { 'meta' => ['campaign_123'] }
        }
      }
    )
    
    # Mock successful rollback at service method level
    @service.stub(:rollback_platform_deployment, { success: true, campaigns_paused: 1, total_campaigns: 1 }) do
      result = @service.rollback_execution
      assert result[:success]
      assert result[:data][:rollback_successful]
    end
  end

  test "rollback_execution fails when rollback not possible" do
    # Execution without rollback data
    result = @service.rollback_execution
    assert_not result[:success]
    assert_includes result[:error], "Execution cannot be rolled back"
  end

  # Status and reporting tests
  test "execution_status returns comprehensive information" do
    @execution_schedule.update!(status: 'executing')
    
    status = @service.execution_status
    
    assert status[:execution_schedule].present?
    assert status[:campaign_plan].present?
    assert status[:platform_status].present?
    assert_equal @execution_schedule.id, status[:execution_schedule][:id]
    assert_equal @campaign_plan.name, status[:campaign_plan][:name]
  end

  test "get_platform_deployment_status returns connection info" do
    status = @service.send(:get_platform_deployment_status)
    
    assert status['meta'].present?
    assert status['meta'][:connected]
  end

  # Performance monitoring tests
  test "should_optimize_platform detects optimization need" do
    performance_data = {
      'ctr' => 0.3, # Below 0.5 threshold
      'cpc' => 6.0  # Above 5.0 threshold
    }
    optimization_rules = {
      'min_ctr' => 0.5,
      'max_cpc' => 5.0
    }
    
    assert @service.send(:should_optimize_platform?, performance_data, optimization_rules)
  end

  test "should_optimize_platform returns false for good performance" do
    performance_data = {
      'ctr' => 2.0, # Above threshold
      'cpc' => 3.0  # Below threshold
    }
    optimization_rules = {
      'min_ctr' => 0.5,
      'max_cpc' => 5.0
    }
    
    assert_not @service.send(:should_optimize_platform?, performance_data, optimization_rules)
  end

  # Error handling tests
  test "handles service errors gracefully" do
    # Mock validation failure
    @service.stub(:validate_execution_preconditions, { success: false, error: 'Pre-execution validation failed', validation_errors: ['Test error'] }) do
      result = @service.call
      assert_not result[:success]
      assert_includes result[:error], 'Pre-execution validation failed'
    end
  end

  test "handles exceptions during execution" do
    # Mock exception during platform deployment
    @service.stub(:execute_on_platforms, ->{ raise StandardError, "Platform API error" }) do
      result = @service.call
      assert_not result[:success]
    end
    
    @execution_schedule.reload
    assert @execution_schedule.failed?
    assert_equal "Platform API error", @execution_schedule.metadata['error_message']
  end

  private

  def setup_platform_connections
    # Clear existing connections
    @user.platform_connections.destroy_all
    
    # Create test connections
    @meta_connection = create_platform_connection('meta')
    @google_connection = create_platform_connection('google_ads')  
    @linkedin_connection = create_platform_connection('linkedin')
  end

  def create_platform_connection(platform)
    credentials = case platform
    when 'meta'
      '{"access_token":"test_meta_token","app_secret":"test_app_secret"}'
    when 'google_ads'
      '{"access_token":"test_google_token","developer_token":"test_dev_token","customer_id":"123-456-7890","refresh_token":"test_refresh_token"}'
    when 'linkedin'
      '{"access_token":"test_linkedin_token"}'
    else
      "{\"access_token\":\"test_#{platform}_token\"}"
    end
    
    PlatformConnection.create!(
      user: @user,
      platform: platform,
      credentials: credentials,
      status: 'active',
      account_id: "test_account_#{platform}",
      account_name: "Test #{platform.titleize} Account",
      last_sync_at: 1.hour.ago,
      metadata: "{\"test\":\"data\"}"
    )
  end

  def setup_platform_service_mocks
    # Mock platform service responses - use a stub object instead of strict mock
    @platform_service_mock = Object.new
    
    def @platform_service_mock.test_platform_connections
      {
        success: true,
        data: { all_connected: true, connection_tests: {} }
      }
    end
    
    @service.instance_variable_set(:@platform_service, @platform_service_mock)
  end

  def mock_platform_client_response(responses = {})
    client_mock = Object.new
    
    responses.each do |method, response|
      client_mock.define_singleton_method(method) { |*args| response }
    end
    
    # Add default methods that might be called
    client_mock.define_singleton_method(:health_check) { { status: 'healthy' } }
    client_mock.define_singleton_method(:rate_limit_status) { { remaining: 1000 } }
    
    client_mock
  end

  def mock_successful_deployment
    successful_responses = {
      create_campaign: { success: true, data: { 'id' => 'campaign_123' } }
    }
    
    mock_client = mock_platform_client_response(successful_responses)
    
    # Mock adsets/ads creation
    @service.stub(:create_meta_adsets, { success: true, count: 1 }) do
      @service.stub(:create_meta_ads, { success: true, count: 1 }) do
        @service.stub(:get_platform_performance, { success: true, data: { 'ctr' => 1.5, 'cpc' => 3.0 } }) do
          
          @user.platform_connections.each do |connection|
            connection.stub(:build_platform_client, mock_client) do
              yield if block_given?
            end
          end
        end
      end
    end
  end

  def mock_failed_deployment
    failed_responses = {
      create_campaign: { success: false, error: 'Platform API error' }
    }
    
    mock_client = mock_platform_client_response(failed_responses)
    
    @user.platform_connections.for_platform('meta').first
         .stub(:build_platform_client, mock_client) do
      yield if block_given?
    end
  end
end