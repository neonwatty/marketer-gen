# frozen_string_literal: true

require 'test_helper'

class PlatformIntegrationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:one)
    @service = PlatformIntegrationService.new(@user, @campaign_plan)
    
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

  test "initializes with correct attributes" do
    assert_equal @user, @service.user
    assert_equal @campaign_plan, @service.campaign_plan
    assert_not_nil @service.platform_configs
  end

  test "initializes without campaign plan" do
    service = PlatformIntegrationService.new(@user)
    assert_equal @user, service.user
    assert_nil service.campaign_plan
  end

  test "get_platform_config returns correct configuration for active connections" do
    config = @service.send(:get_platform_config, 'meta')
    
    assert_equal 'test_meta_token', config['access_token']
    assert_equal 'test_app_secret', config['app_secret']
  end

  test "get_platform_config returns empty hash for inactive platform" do
    @meta_connection.update!(status: 'inactive')
    
    config = @service.send(:get_platform_config, 'meta')
    
    assert_equal({}, config)
  end

  test "get_platform_config returns empty hash for non-existent platform" do
    config = @service.send(:get_platform_config, 'google_ads')
    
    assert_equal({}, config)
  end

  test "get_platform_client returns client for active connection" do
    # Mock the client creation
    mock_client = mock('meta_client')
    ExternalPlatforms::MetaApiClient.expects(:new).with(
      'test_meta_token',
      'test_app_secret'
    ).returns(mock_client)
    
    client = @service.send(:get_platform_client, 'meta')
    
    assert_equal mock_client, client
  end

  test "get_platform_client returns nil for inactive connection" do
    @meta_connection.update!(status: 'inactive')
    
    client = @service.send(:get_platform_client, 'meta')
    
    assert_nil client
  end

  test "get_platform_client returns nil for non-existent connection" do
    client = @service.send(:get_platform_client, 'google_ads')
    
    assert_nil client
  end

  test "test_platform_connections tests all supported platforms" do
    # Mock clients and their health checks
    mock_meta_client = mock('meta_client')
    mock_meta_client.expects(:health_check).returns({ status: :healthy })
    mock_meta_client.expects(:rate_limit_status).returns({ available: true, usage: '10%' })
    
    mock_linkedin_client = mock('linkedin_client')
    mock_linkedin_client.expects(:health_check).returns({ status: :healthy })
    mock_linkedin_client.expects(:rate_limit_status).returns({ available: true, usage: '5%' })
    
    mock_google_ads_client = mock('google_ads_client')
    mock_google_ads_client.expects(:health_check).returns({ status: :healthy })
    mock_google_ads_client.expects(:rate_limit_status).returns({ available: true, usage: '15%' })
    
    # Mock get_platform_client method directly
    @service.expects(:get_platform_client).with('meta').returns(mock_meta_client)
    @service.expects(:get_platform_client).with('google_ads').returns(mock_google_ads_client)
    @service.expects(:get_platform_client).with('linkedin').returns(mock_linkedin_client)
    
    result = @service.test_platform_connections
    
    assert result[:success]
    assert result[:data][:all_connected]
    assert_equal :healthy, result[:data][:connection_tests]['meta'][:health]
    assert_equal :healthy, result[:data][:connection_tests]['linkedin'][:health]
    assert_equal :healthy, result[:data][:connection_tests]['google_ads'][:health]
    assert result[:data][:connection_tests]['meta'][:connected]
    assert result[:data][:connection_tests]['linkedin'][:connected]
    assert result[:data][:connection_tests]['google_ads'][:connected]
  end

  test "test_platform_connections handles connection errors gracefully" do
    # Mock get_platform_client to raise an error for meta platform
    @service.expects(:get_platform_client).with('meta').raises(StandardError.new('Connection failed'))
    @service.expects(:get_platform_client).with('google_ads').returns(nil)
    @service.expects(:get_platform_client).with('linkedin').returns(nil)
    
    result = @service.test_platform_connections
    
    assert result[:success]
    assert_not result[:data][:all_connected]
    assert_not result[:data][:connection_tests]['meta'][:connected]
    assert_includes result[:data][:connection_tests]['meta'][:error], 'Connection failed'
  end

  test "sync_platform syncs data from specific platform" do
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    # Mock the client and sync process
    mock_client = mock('meta_client')
    mock_sync_data = { campaigns: [], accounts: [] }
    
    @service.expects(:get_platform_client).with('meta').returns(mock_client)
    @service.expects(:sync_platform_data).with('meta', mock_client, date_range).returns({
      success: true,
      data: mock_sync_data
    })
    @service.expects(:update_single_platform_data).with('meta', mock_sync_data)
    
    result = @service.sync_platform('meta', date_range)
    
    assert result[:success]
    assert_equal mock_sync_data, result[:data][:data]
  end

  test "sync_platform returns error for unsupported platform" do
    result = @service.sync_platform('unsupported_platform')
    
    assert_not result[:success]
    assert_includes result[:error], 'Unsupported platform'
  end

  test "sync_platform returns error when client not available" do
    result = @service.sync_platform('google_ads') # No connection exists
    
    assert_not result[:success]
    assert_includes result[:error], 'Platform client not available'
  end

  test "sync_all_platforms syncs all connected platforms" do
    date_range = { since: '2024-01-01', until: '2024-01-31' }
    
    # Mock clients
    mock_meta_client = mock('meta_client')
    mock_linkedin_client = mock('linkedin_client')
    
    # Mock sync responses
    mock_meta_data = { campaigns: [{ id: 1, name: 'Test Campaign' }] }
    mock_linkedin_data = { organizations: [{ id: 1, name: 'Test Org' }] }
    
    @service.expects(:get_platform_client).with('meta').returns(mock_meta_client)
    @service.expects(:get_platform_client).with('google_ads').returns(nil)
    @service.expects(:get_platform_client).with('linkedin').returns(mock_linkedin_client)
    
    @service.expects(:sync_platform_data).with('meta', mock_meta_client, date_range).returns({
      success: true,
      data: mock_meta_data
    })
    @service.expects(:sync_platform_data).with('linkedin', mock_linkedin_client, date_range).returns({
      success: true,
      data: mock_linkedin_data
    })
    
    @service.expects(:update_campaign_performance_data).with(anything)
    
    result = @service.sync_all_platforms(date_range)
    
    assert result[:success]
    assert_equal %w[meta linkedin], result[:data][:platforms_synced]
    assert result[:data][:sync_results]['meta'][:success]
    assert result[:data][:sync_results]['linkedin'][:success]
  end

  test "sync_all_platforms handles partial failures" do
    # Mock one successful and one failed sync
    mock_meta_client = mock('meta_client')
    
    @service.expects(:get_platform_client).with('meta').returns(mock_meta_client)
    @service.expects(:get_platform_client).with('google_ads').returns(nil)
    @service.expects(:get_platform_client).with('linkedin').raises(StandardError.new('LinkedIn error'))
    
    @service.expects(:sync_platform_data).with('meta', mock_meta_client, anything).returns({
      success: true,
      data: { campaigns: [] }
    })
    
    result = @service.sync_all_platforms
    
    assert_not result[:success]
    assert_includes result[:error], 'Some platforms failed to sync'
    assert result[:context][:partial_results]['meta'][:success]
    assert_not result[:context][:partial_results]['linkedin'][:success]
  end

  test "get_aggregated_metrics aggregates data from multiple platforms" do
    # Mock successful sync
    sync_results = {
      'meta' => {
        success: true,
        data: {
          campaigns: [
            {
              'performance' => {
                'data' => [
                  {
                    'impressions' => 1000,
                    'clicks' => 50,
                    'spend' => 100.0,
                    'conversions' => [{ 'value' => 5 }],
                    'reach' => 800
                  }
                ]
              }
            }
          ]
        }
      },
      'linkedin' => {
        success: true,
        data: {
          organizations: [
            {
              'ad_accounts' => [
                {
                  'campaigns' => [
                    {
                      'analytics' => {
                        'elements' => [
                          {
                            'impressions' => 500,
                            'clicks' => 25,
                            'costInUsd' => 50.0,
                            'externalWebsiteConversions' => 3,
                            'oneClickLeads' => 2
                          }
                        ]
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    }
    
    @service.expects(:sync_all_platforms).returns({
      success: true,
      data: { sync_results: sync_results }
    })
    
    result = @service.get_aggregated_metrics
    
    assert result[:success]
    
    totals = result[:data][:aggregated_metrics][:totals]
    assert_equal 1500, totals[:impressions] # 1000 + 500
    assert_equal 75, totals[:clicks] # 50 + 25
    assert_equal 150.0, totals[:spend] # 100 + 50
    assert_equal 10, totals[:conversions] # 5 + 3 + 2
    
    # Check derived metrics
    assert_equal 5.0, totals[:ctr] # (75/1500) * 100
    assert_equal 2.0, totals[:cpc] # 150/75
    assert_equal 13.33, totals[:conversion_rate] # (10/75) * 100
  end

  test "export_performance_data generates JSON export" do
    mock_metrics = {
      aggregated_metrics: {
        totals: { impressions: 1000, clicks: 50 },
        platform_breakdown: { 'meta' => { impressions: 1000 } }
      },
      date_range: 'Last 30 days',
      generated_at: Time.current
    }
    
    @service.expects(:get_aggregated_metrics).returns({
      success: true,
      data: mock_metrics
    })
    
    result = @service.export_performance_data('json')
    
    assert result[:success]
    assert_equal 'json', result[:data][:format]
    assert result[:data][:content].present?
    assert_includes result[:data][:filename], '.json'
  end

  test "export_performance_data generates CSV export" do
    mock_metrics = {
      aggregated_metrics: {
        totals: { impressions: 1000, clicks: 50, spend: 100.0, conversions: 5, reach: 800, ctr: 5.0, cpc: 2.0, conversion_rate: 10.0 },
        platform_breakdown: { 
          'meta' => { impressions: 1000, clicks: 50, spend: 100.0, conversions: 5, reach: 800 }
        }
      },
      date_range: 'Last 30 days',
      generated_at: Time.current
    }
    
    @service.expects(:get_aggregated_metrics).returns({
      success: true,
      data: mock_metrics
    })
    
    result = @service.export_performance_data('csv')
    
    assert result[:success]
    assert_equal 'csv', result[:data][:format]
    assert result[:data][:content].present?
    assert_includes result[:data][:filename], '.csv'
    assert_includes result[:data][:content], 'Platform,Impressions,Clicks'
    assert_includes result[:data][:content], 'Meta,1000,50'
  end

  test "export_performance_data returns error for unsupported format" do
    result = @service.export_performance_data('xml')
    
    assert_not result[:success]
    assert_includes result[:error], 'Unsupported export format'
  end

  test "extract_meta_metrics correctly extracts metrics" do
    data = {
      campaigns: [
        {
          'performance' => {
            'data' => [
              {
                'impressions' => 1000,
                'clicks' => 50,
                'spend' => 100.50,
                'conversions' => [{ 'value' => 3 }, { 'value' => 2 }],
                'reach' => 800
              }
            ]
          }
        }
      ]
    }
    
    metrics = @service.send(:extract_meta_metrics, data)
    
    assert_equal 1000, metrics[:impressions]
    assert_equal 50, metrics[:clicks]
    assert_equal 100.50, metrics[:spend]
    assert_equal 5, metrics[:conversions]
    assert_equal 800, metrics[:reach]
  end

  test "extract_linkedin_metrics correctly extracts metrics" do
    data = {
      organizations: [
        {
          'ad_accounts' => [
            {
              'campaigns' => [
                {
                  'analytics' => {
                    'elements' => [
                      {
                        'impressions' => 500,
                        'clicks' => 25,
                        'costInUsd' => 50.0,
                        'externalWebsiteConversions' => 3,
                        'oneClickLeads' => 2
                      }
                    ]
                  }
                }
              ]
            }
          ]
        }
      ]
    }
    
    metrics = @service.send(:extract_linkedin_metrics, data)
    
    assert_equal 500, metrics[:impressions]
    assert_equal 25, metrics[:clicks]
    assert_equal 50.0, metrics[:spend]
    assert_equal 5, metrics[:conversions] # 3 + 2
    assert_equal 500, metrics[:reach] # Uses impressions as proxy
  end

  test "update_campaign_performance_data updates campaign plan" do
    platform_results = {
      'meta' => { success: true, data: { campaigns: [] } },
      'linkedin' => { success: true, data: { organizations: [] } }
    }
    
    @service.send(:update_campaign_performance_data, platform_results)
    
    @campaign_plan.reload
    performance_data = @campaign_plan.performance_data
    
    assert performance_data['meta']['last_sync']
    assert_equal 'synced', performance_data['meta']['status']
    assert performance_data['linkedin']['last_sync']
    assert_equal 'synced', performance_data['linkedin']['status']
    
    assert @campaign_plan.metadata['last_platform_sync']
    assert_equal %w[meta linkedin], @campaign_plan.metadata['synced_platforms']
  end

  test "update_single_platform_data updates campaign plan for single platform" do
    test_data = { 'campaigns' => [{ 'id' => 1, 'name' => 'Test' }] }
    
    @service.send(:update_single_platform_data, 'meta', test_data)
    
    @campaign_plan.reload
    performance_data = @campaign_plan.performance_data
    
    assert performance_data['meta']['last_sync']
    assert_equal test_data, performance_data['meta']['data']
    assert_equal 'synced', performance_data['meta']['status']
    assert @campaign_plan.metadata['last_meta_sync']
  end
end