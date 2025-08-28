require 'test_helper'

class SyncRecordTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @platform_connection = platform_connections(:fixture_meta_connection)
    @sync_record = sync_records(:pending_sync)
  end

  test "should be valid with valid attributes" do
    sync_record = SyncRecord.new(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'full_sync',
      status: 'pending'
    )
    assert sync_record.valid?
  end

  test "should require platform_connection" do
    sync_record = SyncRecord.new(
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'full_sync'
    )
    assert_not sync_record.valid?
    assert_includes sync_record.errors[:platform_connection], "must exist"
  end

  test "should require external_id" do
    sync_record = SyncRecord.new(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      sync_type: 'full_sync'
    )
    assert_not sync_record.valid?
    assert_includes sync_record.errors[:external_id], "can't be blank"
  end

  test "should require entity_type" do
    sync_record = SyncRecord.new(
      platform_connection: @platform_connection,
      external_id: 'test_123',
      sync_type: 'full_sync'
    )
    assert_not sync_record.valid?
    assert_includes sync_record.errors[:entity_type], "can't be blank"
  end

  test "should validate sync_type inclusion" do
    sync_record = SyncRecord.new(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'invalid_sync'
    )
    assert_not sync_record.valid?
    assert_includes sync_record.errors[:sync_type], "is not included in the list"
  end

  test "should validate status inclusion" do
    sync_record = SyncRecord.new(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'full_sync',
      status: 'invalid_status'
    )
    assert_not sync_record.valid?
    assert_includes sync_record.errors[:status], "is not included in the list"
  end

  test "should validate direction inclusion" do
    sync_record = SyncRecord.new(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'full_sync',
      direction: 'invalid_direction'
    )
    assert_not sync_record.valid?
    assert_includes sync_record.errors[:direction], "is not included in the list"
  end

  test "should set defaults on create" do
    sync_record = SyncRecord.create!(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'test_123',
      sync_type: 'full_sync'
    )
    
    assert_equal 'pending', sync_record.status
    assert_equal 'bidirectional', sync_record.direction
    assert_equal 0, sync_record.retry_count
    assert_not_nil sync_record.metadata
  end

  test "should have status query methods" do
    assert @sync_record.pending?
    assert_not @sync_record.in_progress?
    assert_not @sync_record.completed?
    assert_not @sync_record.failed?
    assert_not @sync_record.has_conflict?
  end

  test "mark_in_progress! should update status and timestamps" do
    @sync_record.mark_in_progress!
    
    assert @sync_record.in_progress?
    assert_not_nil @sync_record.started_at
    assert_not_nil @sync_record.metadata['processing_started']
  end

  test "mark_completed! should update status and timestamps" do
    result_data = { entities_synced: 5 }
    @sync_record.mark_completed!(result_data)
    
    assert @sync_record.completed?
    assert_not_nil @sync_record.completed_at
    assert_equal result_data.stringify_keys, @sync_record.metadata['result']
  end

  test "mark_failed! should update status and error" do
    error_message = "Connection timeout"
    error_data = { timeout: 30 }
    
    @sync_record.mark_failed!(error_message, error_data)
    
    assert @sync_record.failed?
    assert_equal error_message, @sync_record.error_message
    assert_not_nil @sync_record.completed_at
    assert_equal error_data.stringify_keys, @sync_record.metadata['error_data']
  end

  test "mark_conflict! should update status and conflict data" do
    conflict_details = {
      conflicts: [{ field: 'name', local_value: 'A', external_value: 'B' }]
    }
    
    @sync_record.mark_conflict!(conflict_details)
    
    assert @sync_record.has_conflict?
    assert_equal conflict_details.deep_stringify_keys, @sync_record.conflict_data
    assert @sync_record.metadata['requires_manual_resolution']
  end

  test "sync_duration should calculate correctly" do
    @sync_record.update!(
      started_at: 2.minutes.ago,
      completed_at: 1.minute.ago
    )
    
    duration = @sync_record.sync_duration
    assert duration > 50
    assert duration < 70
  end

  test "data_changed? should detect data differences" do
    @sync_record.local_data = { name: 'Campaign A' }
    @sync_record.external_data = { name: 'Campaign B' }
    
    assert @sync_record.data_changed?
    
    @sync_record.external_data = { name: 'Campaign A' }
    assert_not @sync_record.data_changed?
  end

  test "conflict_resolution_required? should work correctly" do
    assert_not @sync_record.conflict_resolution_required?
    
    @sync_record.status = 'conflict_detected'
    @sync_record.conflict_data = { conflicts: ['test'] }
    
    assert @sync_record.conflict_resolution_required?
  end

  test "get_conflict_summary should return summary" do
    @sync_record.update!(
      status: 'conflict_detected',
      conflict_data: {
        conflicts: [{ field: 'name' }],
        local_version: { data: 'local' },
        external_version: { data: 'external' }
      }
    )
    
    summary = @sync_record.get_conflict_summary
    
    assert_equal "#{@sync_record.entity_type}##{@sync_record.external_id}", summary[:entity]
    assert_equal @platform_connection.platform, summary[:platform]
    assert_includes summary[:conflicts], { 'field' => 'name' }
  end

  test "retry_sync! should increment retry count and reset status" do
    @sync_record.update!(status: 'failed', error_message: 'Test error')
    
    assert @sync_record.retry_sync!
    
    assert @sync_record.pending?
    assert_nil @sync_record.error_message
    assert_equal 1, @sync_record.retry_count
    assert_not_nil @sync_record.metadata['retried_at']
  end

  test "can_retry? should work correctly" do
    @sync_record.update!(status: 'failed', retry_count: 2)
    assert @sync_record.can_retry?
    
    @sync_record.update!(retry_count: 3)
    assert_not @sync_record.can_retry?
    
    @sync_record.update!(status: 'completed', retry_count: 0)
    assert_not @sync_record.can_retry?
  end

  test "hash_data should create consistent hashes" do
    data = { name: 'Test', id: 123 }
    hash1 = @sync_record.hash_data(data)
    hash2 = @sync_record.hash_data(data)
    
    assert_equal hash1, hash2
    assert hash1.is_a?(String)
    assert_equal 64, hash1.length
  end

  test "data_fingerprint should work correctly" do
    @sync_record.local_data = { name: 'Local' }
    @sync_record.external_data = { name: 'External' }
    
    fingerprint = @sync_record.data_fingerprint
    
    assert fingerprint[:local]
    assert fingerprint[:external]
    assert_not_equal fingerprint[:local], fingerprint[:external]
  end

  # Scope tests
  test "pending scope should return pending records" do
    pending_count = SyncRecord.pending.count
    assert pending_count > 0
    
    SyncRecord.pending.each do |record|
      assert_equal 'pending', record.status
    end
  end

  test "with_conflicts scope should return conflict records" do
    @sync_record.update!(status: 'conflict_detected')
    conflicts = SyncRecord.with_conflicts
    
    assert_includes conflicts, @sync_record
  end

  test "for_entity_type scope should filter by entity type" do
    campaigns = SyncRecord.for_entity_type('campaigns')
    campaigns.each do |record|
      assert_equal 'campaigns', record.entity_type
    end
  end

  test "recent scope should return recent records" do
    old_record = SyncRecord.create!(
      platform_connection: @platform_connection,
      entity_type: 'campaigns',
      external_id: 'old_123',
      sync_type: 'full_sync',
      created_at: 2.days.ago
    )
    
    recent_records = SyncRecord.recent
    assert_not_includes recent_records, old_record
  end

  test "platform method should return platform from connection" do
    assert_equal @platform_connection.platform, @sync_record.platform
  end
end