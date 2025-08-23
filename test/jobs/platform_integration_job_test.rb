# frozen_string_literal: true

require 'test_helper'

class PlatformIntegrationJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:one)
    
    # Clear any existing platform connections for the test user
    @user.platform_connections.destroy_all
    
    # Create test platform connections
    @meta_connection = PlatformConnection.create!(
      user: @user,
      platform: 'meta',
      credentials: {
        access_token: 'test_meta_token',
        app_secret: 'test_app_secret'
      }.to_json,
      status: 'active'
    )
    
    @linkedin_connection = PlatformConnection.create!(
      user: @user,
      platform: 'linkedin',
      credentials: {
        access_token: 'test_linkedin_token'
      }.to_json,
      status: 'active'
    )
  end

  test "should enqueue job with correct arguments" do
    assert_enqueued_with(job: PlatformIntegrationJob, args: [@user.id, @campaign_plan.id, { 'operation' => 'sync_all' }]) do
      PlatformIntegrationJob.perform_later(@user.id, @campaign_plan.id, { 'operation' => 'sync_all' })
    end
  end

  test "perform sync_all_platforms operation successfully" do
    # Mock the service and its methods
    mock_service = mock('platform_integration_service')
    mock_service.expects(:sync_all_platforms).with({}).returns({
      success: true,
      data: {
        platforms_synced: ['meta', 'linkedin'],
        sync_results: {}
      }
    })
    mock_service.stubs(:user).returns(@user)
    mock_service.stubs(:campaign_plan).returns(@campaign_plan)
    
    PlatformIntegrationService.expects(:new).with(@user, @campaign_plan).returns(mock_service)
    
    job = PlatformIntegrationJob.new
    result = job.perform(@user.id, @campaign_plan.id, { 'operation' => 'sync_all' })
    
    assert result[:success]
  end

  test "perform sync_platform operation successfully" do
    # Mock the service and its methods
    mock_service = mock('platform_integration_service')
    mock_service.expects(:sync_platform).with('meta', {}).returns({
      success: true,
      data: { campaigns: [] }
    })
    mock_service.stubs(:user).returns(@user)
    
    PlatformIntegrationService.expects(:new).with(@user, @campaign_plan).returns(mock_service)
    
    job = PlatformIntegrationJob.new
    result = job.perform(@user.id, @campaign_plan.id, {
      'operation' => 'sync_platform',
      'platform' => 'meta'
    })
    
    assert result[:success]
  end

  test "perform test_connections operation successfully" do
    # Mock the service and its methods
    mock_service = mock('platform_integration_service')
    mock_service.expects(:test_platform_connections).returns({
      success: true,
      data: {
        connection_tests: {
          'meta' => { connected: true },
          'linkedin' => { connected: true }
        }
      }
    })
    mock_service.stubs(:user).returns(@user)
    
    PlatformIntegrationService.expects(:new).with(@user, nil).returns(mock_service)
    
    job = PlatformIntegrationJob.new
    result = job.perform(@user.id, nil, { 'operation' => 'test_connections' })
    
    assert result[:success]
  end

  test "perform defaults to sync_all when no operation specified" do
    # Mock the service and its methods
    mock_service = mock('platform_integration_service')
    mock_service.expects(:sync_all_platforms).with({}).returns({
      success: true,
      data: { platforms_synced: [] }
    })
    mock_service.stubs(:user).returns(@user)
    mock_service.stubs(:campaign_plan).returns(nil)
    
    PlatformIntegrationService.expects(:new).with(@user, nil).returns(mock_service)
    
    job = PlatformIntegrationJob.new
    result = job.perform(@user.id, nil, {})
    
    assert result[:success]
  end

  test "perform handles user not found error" do
    assert_raises ActiveRecord::RecordNotFound do
      job = PlatformIntegrationJob.new
      job.perform(99999, nil, {})
    end
  end

  test "perform handles campaign plan not found error" do
    assert_raises ActiveRecord::RecordNotFound do
      job = PlatformIntegrationJob.new
      job.perform(@user.id, 99999, {})
    end
  end

  test "perform handles service errors and re-raises them" do
    # Mock the service to raise an error
    mock_service = mock('platform_integration_service')
    mock_service.expects(:sync_all_platforms).raises(StandardError.new('Service error'))
    mock_service.stubs(:user).returns(@user)
    mock_service.stubs(:campaign_plan).returns(nil)
    
    PlatformIntegrationService.expects(:new).returns(mock_service)
    
    job = PlatformIntegrationJob.new
    
    assert_raises StandardError do
      job.perform(@user.id, nil, {})
    end
  end

  test "sync_all_platforms triggers analytics refresh when requested" do
    # Mock the service
    mock_service = mock('platform_integration_service')
    mock_service.expects(:sync_all_platforms).returns({
      success: true,
      data: { platforms_synced: ['meta'] }
    })
    mock_service.stubs(:user).returns(@user)
    mock_service.stubs(:campaign_plan).returns(@campaign_plan)
    
    # Mock campaign plan analytics refresh
    @campaign_plan.expects(:analytics_enabled?).returns(true)
    @campaign_plan.expects(:refresh_analytics!).returns(true)
    
    job = PlatformIntegrationJob.new
    result = job.send(:sync_all_platforms, mock_service, {}, {
      'trigger_analytics_refresh' => 'true'
    })
    
    assert result[:success]
  end

  test "sync_single_platform updates connection status on success" do
    # Mock the service
    mock_service = mock('platform_integration_service')
    mock_service.expects(:sync_platform).returns({
      success: true,
      data: { campaigns: [] }
    })
    mock_service.stubs(:user).returns(@user)
    
    job = PlatformIntegrationJob.new
    result = job.send(:sync_single_platform, mock_service, 'meta', {}, {})
    
    assert result[:success]
    
    # Check that connection status was updated
    @meta_connection.reload
    assert_not_nil @meta_connection.last_sync_at
  end

  test "sync_single_platform updates connection with error on failure" do
    # Mock the service
    mock_service = mock('platform_integration_service')
    mock_service.expects(:sync_platform).returns({
      success: false,
      error: 'API error'
    })
    mock_service.stubs(:user).returns(@user)
    
    job = PlatformIntegrationJob.new
    result = job.send(:sync_single_platform, mock_service, 'meta', {}, {})
    
    assert_not result[:success]
    
    # Check that connection status was updated with error
    @meta_connection.reload
    assert_equal 'error', @meta_connection.status
  end

  test "test_platform_connections updates connection statuses" do
    # Mock the service
    mock_service = mock('platform_integration_service')
    mock_service.expects(:test_platform_connections).returns({
      success: true,
      data: {
        connection_tests: {
          'meta' => { connected: true },
          'linkedin' => { connected: false, error: 'Auth failed' }
        }
      }
    })
    mock_service.stubs(:user).returns(@user)
    
    job = PlatformIntegrationJob.new
    result = job.send(:test_platform_connections, mock_service, {})
    
    assert result[:success]
    
    # Check that connection statuses were updated
    @meta_connection.reload
    @linkedin_connection.reload
    
    assert_not_nil @meta_connection.last_sync_at
    assert_equal 'error', @linkedin_connection.status
  end

  test "parse_date_range handles valid date strings" do
    date_options = {
      'since' => '2024-01-01',
      'until' => '2024-01-31',
      'time_increment' => 'all_days'
    }
    
    job = PlatformIntegrationJob.new
    parsed = job.send(:parse_date_range, date_options)
    
    assert_equal Date.parse('2024-01-01'), parsed[:since]
    assert_equal Date.parse('2024-01-31'), parsed[:until]
    assert_equal 'all_days', parsed[:time_increment]
  end

  test "parse_date_range handles invalid date strings gracefully" do
    date_options = {
      'since' => 'invalid-date',
      'until' => '2024-01-31'
    }
    
    job = PlatformIntegrationJob.new
    parsed = job.send(:parse_date_range, date_options)
    
    # Should return empty hash on parsing error
    assert_empty parsed
  end

  test "parse_date_range handles nil and non-hash input" do
    job = PlatformIntegrationJob.new
    
    assert_empty job.send(:parse_date_range, nil)
    assert_empty job.send(:parse_date_range, "not a hash")
    assert_empty job.send(:parse_date_range, [])
  end

  # Test class methods for job scheduling
  test "sync_all_platforms class method enqueues job correctly" do
    date_range = { since: Date.current - 7.days, until: Date.current }
    
    assert_enqueued_with(
      job: PlatformIntegrationJob,
      args: [
        @user.id,
        @campaign_plan.id,
        {
          'operation' => 'sync_all',
          'date_range' => {
            'since' => date_range[:since].strftime('%Y-%m-%d'),
            'until' => date_range[:until].strftime('%Y-%m-%d')
          },
          'trigger_analytics_refresh' => 'true',
          'send_notification' => 'true'
        }
      ]
    ) do
      PlatformIntegrationJob.sync_all_platforms(
        @user,
        @campaign_plan,
        date_range: date_range,
        trigger_analytics_refresh: true,
        send_notification: true
      )
    end
  end

  test "sync_platform class method enqueues job correctly" do
    date_range = { since: Date.current - 7.days, until: Date.current }
    
    assert_enqueued_with(
      job: PlatformIntegrationJob,
      args: [
        @user.id,
        @campaign_plan.id,
        {
          'operation' => 'sync_platform',
          'platform' => 'meta',
          'date_range' => {
            'since' => date_range[:since].strftime('%Y-%m-%d'),
            'until' => date_range[:until].strftime('%Y-%m-%d')
          }
        }
      ]
    ) do
      PlatformIntegrationJob.sync_platform(
        @user,
        'meta',
        @campaign_plan,
        date_range: date_range
      )
    end
  end

  test "test_connections class method enqueues job correctly" do
    assert_enqueued_with(
      job: PlatformIntegrationJob,
      args: [
        @user.id,
        nil,
        {
          'operation' => 'test_connections',
          'send_notification' => 'true'
        }
      ]
    ) do
      PlatformIntegrationJob.test_connections(
        @user,
        send_notification: true
      )
    end
  end

  test "serialize_date_range handles Date objects correctly" do
    date_range = {
      since: Date.new(2024, 1, 1),
      until: Date.new(2024, 1, 31),
      time_increment: 'all_days'
    }
    
    result = PlatformIntegrationJob.send(:serialize_date_range, date_range)
    
    assert_equal '2024-01-01', result['since']
    assert_equal '2024-01-31', result['until']
    assert_equal 'all_days', result['time_increment']
  end

  test "serialize_date_range handles nil and empty input" do
    assert_empty PlatformIntegrationJob.send(:serialize_date_range, nil)
    assert_empty PlatformIntegrationJob.send(:serialize_date_range, {})
    assert_empty PlatformIntegrationJob.send(:serialize_date_range, "not a hash")
  end

  test "stringify_options converts symbol keys and values to strings" do
    options = {
      trigger_analytics_refresh: true,
      send_notification: false,
      custom_option: :symbol_value
    }
    
    result = PlatformIntegrationJob.send(:stringify_options, options)
    
    assert_equal 'true', result['trigger_analytics_refresh']
    assert_equal 'false', result['send_notification']  
    assert_equal 'symbol_value', result['custom_option']
  end
end