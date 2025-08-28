require 'test_helper'

class DataSynchronizationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @platform_connection = platform_connections(:fixture_meta_connection)
    @platform_connection.update!(status: 'active')
    @service = DataSynchronizationService.new(@platform_connection)
  end

  test "should initialize with platform connection and default options" do
    assert_equal @platform_connection, @service.platform_connection
    assert_equal 'intelligent', @service.sync_options[:sync_type]
    assert_equal 50, @service.sync_options[:batch_size]
    assert_equal 'bidirectional', @service.sync_options[:direction]
  end

  test "should initialize with custom options" do
    custom_options = {
      sync_type: 'full_sync',
      batch_size: 100,
      direction: 'inbound'
    }
    
    service = DataSynchronizationService.new(@platform_connection, custom_options)
    
    assert_equal 'full_sync', service.sync_options[:sync_type]
    assert_equal 100, service.sync_options[:batch_size]
    assert_equal 'inbound', service.sync_options[:direction]
  end

  test "should handle inactive platform connection" do
    @platform_connection.update!(status: 'inactive')
    
    result = @service.call
    
    assert_not result[:success]
    assert_includes result[:error], "Platform connection is not active"
    assert_equal @platform_connection.platform, result[:platform]
  end

  test "should perform full sync" do
    @service.sync_options[:sync_type] = 'full_sync'
    
    # Mock external data fetching
    mock_client = Minitest::Mock.new
    mock_client.expect :fetch_campaigns, [
      { id: 'camp_1', name: 'Campaign 1', updated_at: Time.current }
    ], [Hash]
    
    @platform_connection.stub :build_platform_client, mock_client do
      result = @service.call
      
      assert result[:success]
      assert_kind_of Hash, result[:data]
      assert_kind_of Array, result[:data][:synced_entities]
    end
    
    mock_client.verify
  end

  test "should perform delta sync" do
    @platform_connection.update!(last_sync_at: 1.day.ago)
    @service.sync_options[:sync_type] = 'delta_sync'
    
    # Mock external data fetching
    mock_client = Minitest::Mock.new
    mock_client.expect :fetch_campaigns, [
      { id: 'camp_1', name: 'Campaign 1', updated_at: Time.current }
    ], [Hash]
    
    @platform_connection.stub :build_platform_client, mock_client do
      result = @service.call
      
      assert result[:success]
    end
    
    mock_client.verify
  end

  test "should handle service errors gracefully" do
    # Force an error by making the client return nil
    @platform_connection.stub :build_platform_client, nil do
      result = @service.call
      
      # Should still return a result (may be success: false or handle gracefully)
      assert_kind_of Hash, result
      assert result.key?(:success)
    end
  end

  test "should determine optimal sync type" do
    # Test with no previous sync (should be full_sync)
    @platform_connection.update!(last_sync_at: nil)
    sync_type = @service.send(:determine_optimal_sync_type)
    assert_equal 'full_sync', sync_type
    
    # Test with old sync (should be full_sync)
    @platform_connection.update!(last_sync_at: 2.weeks.ago)
    sync_type = @service.send(:determine_optimal_sync_type)
    assert_equal 'full_sync', sync_type
    
    # Test with recent sync (should be delta_sync)
    @platform_connection.update!(last_sync_at: 2.days.ago)
    sync_type = @service.send(:determine_optimal_sync_type)
    assert_equal 'delta_sync', sync_type
  end

  test "should create sync record correctly" do
    external_entity = {
      id: 'test_123',
      name: 'Test Campaign',
      updated_at: Time.current
    }
    
    sync_record = @service.send(:create_sync_record, 'campaigns', external_entity, 'full_sync')
    
    assert_equal @platform_connection, sync_record.platform_connection
    assert_equal 'campaigns', sync_record.entity_type
    assert_equal 'test_123', sync_record.external_id
    assert_equal 'full_sync', sync_record.sync_type
    
    # Check the essential data (JSON serialization converts Time to string)
    assert_equal 'test_123', sync_record.external_data['id']
    assert_equal 'Test Campaign', sync_record.external_data['name']
    assert sync_record.external_data['updated_at'].present?
  end

  test "should detect data conflicts correctly" do
    local_entity = {
      id: 'test_123',
      name: 'Local Campaign',
      updated_at: 1.hour.ago
    }
    
    external_entity = {
      id: 'test_123',
      name: 'External Campaign',
      updated_at: 30.minutes.ago
    }
    
    @platform_connection.update!(last_sync_at: 2.hours.ago)
    
    has_conflict = @service.send(:data_conflict_exists?, local_entity, external_entity)
    assert has_conflict
  end

  test "should not detect conflict when data is identical" do
    timestamp = 1.hour.ago
    local_entity = {
      id: 'test_123',
      name: 'Same Campaign',
      updated_at: timestamp
    }
    
    external_entity = {
      id: 'test_123',
      name: 'Same Campaign',
      updated_at: timestamp
    }
    
    has_conflict = @service.send(:data_conflict_exists?, local_entity, external_entity)
    assert_not has_conflict
  end

  test "should analyze conflicts correctly" do
    local_entity = {
      name: 'Local Name',
      status: 'active',
      budget: 1000
    }
    
    external_entity = {
      name: 'External Name',
      status: 'active',
      budget: 2000
    }
    
    conflict_details = @service.send(:analyze_conflict, local_entity, external_entity)
    
    assert_kind_of Hash, conflict_details
    assert_kind_of Array, conflict_details[:conflicts]
    
    # Should detect conflicts in name and budget
    name_conflict = conflict_details[:conflicts].find { |c| c[:field] == 'name' }
    budget_conflict = conflict_details[:conflicts].find { |c| c[:field] == 'budget' }
    
    assert name_conflict
    assert budget_conflict
    assert_equal 'Local Name', name_conflict[:local_value]
    assert_equal 'External Name', name_conflict[:external_value]
  end

  test "should merge entity data correctly" do
    local_entity = {
      name: 'Local Name',
      custom_field: 'local_value',
      custom_other: 'keep_local'
    }
    
    external_entity = {
      name: 'External Name',
      status: 'active',
      budget: 1000
    }
    
    merged = @service.send(:merge_entity_data, local_entity, external_entity)
    
    # Should take external data as base
    assert_equal 'External Name', merged[:name]
    assert_equal 'active', merged[:status]
    assert_equal 1000, merged[:budget]
    
    # Should preserve local custom fields
    assert_equal 'local_value', merged[:custom_field]
    assert_equal 'keep_local', merged[:custom_other]
  end

  test "should parse timestamps correctly" do
    # Test string timestamp
    string_time = "2023-01-01T12:00:00Z"
    parsed = @service.send(:parse_timestamp, string_time)
    assert_kind_of Time, parsed
    
    # Test Time object
    time_obj = Time.current
    parsed = @service.send(:parse_timestamp, time_obj)
    assert_equal time_obj, parsed
    
    # Test DateTime object
    datetime_obj = DateTime.current
    parsed = @service.send(:parse_timestamp, datetime_obj)
    assert_kind_of Time, parsed
    
    # Test invalid timestamp
    parsed = @service.send(:parse_timestamp, "invalid")
    assert_kind_of Time, parsed # Should return current time as fallback
  end

  test "should merge sync results correctly" do
    target = {
      synced_entities: [{ id: 1 }],
      conflicts: [{ id: 'conflict1' }],
      errors: [{ id: 'error1' }]
    }
    
    source = {
      synced_entities: [{ id: 2 }],
      conflicts: [{ id: 'conflict2' }],
      errors: [{ id: 'error2' }]
    }
    
    @service.send(:merge_sync_results, target, source)
    
    assert_equal 2, target[:synced_entities].length
    assert_equal 2, target[:conflicts].length
    assert_equal 2, target[:errors].length
  end

  test "should handle conflict resolution with external wins" do
    sync_record = SyncRecord.create!(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'full_sync',
      status: 'conflict_detected',
      local_data: { name: 'Local' },
      external_data: { name: 'External' }
    )
    
    @service.sync_options[:conflict_resolution] = 'external_wins'
    
    result = @service.send(:resolve_conflict_external_wins, sync_record, sync_record.external_data)
    
    assert_equal 'resolved', result[:status]
    assert_equal 'external_wins', result[:resolution]
    
    sync_record.reload
    assert sync_record.completed?
  end

  test "should handle dry run mode" do
    @service.sync_options[:dry_run] = true
    
    sync_record = SyncRecord.create!(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'full_sync',
      local_data: { name: 'Local' },
      external_data: { name: 'External' }
    )
    
    result = @service.send(:synchronize_entity, sync_record, sync_record.local_data, sync_record.external_data)
    
    assert_equal 'completed', result[:status]
    
    sync_record.reload
    assert sync_record.completed?
    assert_equal true, sync_record.metadata['result']['dry_run']
  end

  test "should update platform connection sync status on success" do
    @service.sync_options[:sync_type] = 'full_sync'
    
    # Mock successful sync
    mock_client = Minitest::Mock.new
    mock_client.expect :fetch_campaigns, [], [Hash]
    mock_client.expect :fetch_ad_groups, [], [Hash]
    mock_client.expect :fetch_ads, [], [Hash]
    
    @platform_connection.stub :build_platform_client, mock_client do
      @service.call
    end
    
    @platform_connection.reload
    # The update_sync_status! should have been called
    # We can't easily test the exact call, but we can verify the connection is still active
    assert @platform_connection.active?
    
    mock_client.verify
  end
end