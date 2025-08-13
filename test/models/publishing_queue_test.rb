require "test_helper"

class PublishingQueueTest < ActiveSupport::TestCase
  def setup
    @campaign = campaigns(:summer_launch)
    @content_schedule = ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 1,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: 1.hour.from_now,
      priority: 3
    )
    
    @publishing_queue = PublishingQueue.new(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.from_now
    )
  end

  test "should be valid with required attributes" do
    assert @publishing_queue.valid?
  end

  test "should require content_schedule" do
    @publishing_queue.content_schedule = nil
    assert_not @publishing_queue.valid?
    assert_includes @publishing_queue.errors[:content_schedule], "must exist"
  end

  test "should require scheduled_for" do
    @publishing_queue.scheduled_for = nil
    assert_not @publishing_queue.valid?
    assert_includes @publishing_queue.errors[:scheduled_for], "can't be blank"
  end

  test "should set defaults on creation" do
    queue = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.from_now
    )
    
    assert_equal 0, queue.retry_count
    assert_equal 3, queue.max_retries
    assert_equal 'pending', queue.processing_status
    assert_not_nil queue.processing_metadata
  end

  test "should generate batch_id after creation" do
    queue = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.from_now
    )
    
    queue.reload
    assert_not_nil queue.batch_id
    assert queue.batch_id.start_with?('batch_')
  end

  test "should identify ready for processing items" do
    # Create item ready for processing
    ready_item = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 5.minutes.ago,
      processing_status: 'pending'
    )
    
    # Create item not ready (future scheduled time)
    future_item = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.from_now,
      processing_status: 'pending'
    )
    
    ready_items = PublishingQueue.ready_for_processing
    assert_includes ready_items, ready_item
    assert_not_includes ready_items, future_item
  end

  test "should identify overdue items" do
    overdue_item = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.ago,
      processing_status: 'pending'
    )
    
    current_item = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.from_now,
      processing_status: 'pending'
    )
    
    overdue_items = PublishingQueue.overdue
    assert_includes overdue_items, overdue_item
    assert_not_includes overdue_items, current_item
  end

  test "should transition from pending to processing" do
    @publishing_queue.save!
    
    assert @publishing_queue.may_start_processing?
    @publishing_queue.start_processing!
    
    assert_equal 'processing', @publishing_queue.processing_status
    assert_not_nil @publishing_queue.attempted_at
    assert_not_nil @publishing_queue.processing_metadata['processing_started_at']
  end

  test "should complete processing successfully" do
    @publishing_queue.processing_status = 'processing'
    @publishing_queue.save!
    
    assert @publishing_queue.may_complete_processing?
    @publishing_queue.complete_processing!
    
    assert_equal 'completed', @publishing_queue.processing_status
    assert_not_nil @publishing_queue.completed_at
    assert_not_nil @publishing_queue.processing_metadata['completed_at']
  end

  test "should handle processing failure" do
    @publishing_queue.processing_status = 'processing'
    @publishing_queue.retry_count = 0
    @publishing_queue.save!
    
    assert @publishing_queue.may_fail_processing?
    @publishing_queue.fail_processing!
    
    assert_equal 'failed', @publishing_queue.processing_status
    assert_equal 1, @publishing_queue.retry_count
    assert_not_nil @publishing_queue.processing_metadata['failed_at']
  end

  test "should check if can retry" do
    @publishing_queue.retry_count = 2
    @publishing_queue.max_retries = 3
    assert @publishing_queue.can_retry?
    
    @publishing_queue.retry_count = 3
    assert_not @publishing_queue.can_retry?
  end

  test "should calculate retries remaining" do
    @publishing_queue.retry_count = 1
    @publishing_queue.max_retries = 3
    assert_equal 2, @publishing_queue.retries_remaining
    
    @publishing_queue.retry_count = 3
    assert_equal 0, @publishing_queue.retries_remaining
  end

  test "should detect overdue status" do
    @publishing_queue.scheduled_for = 1.hour.ago
    @publishing_queue.processing_status = 'pending'
    assert @publishing_queue.is_overdue?
    
    @publishing_queue.processing_status = 'completed'
    assert_not @publishing_queue.is_overdue?
  end

  test "should calculate time until processing" do
    @publishing_queue.scheduled_for = 2.hours.from_now
    @publishing_queue.processing_status = 'pending'
    
    time_until = @publishing_queue.time_until_processing
    assert time_until.include?("hour")
    
    @publishing_queue.scheduled_for = 1.hour.ago
    assert_nil @publishing_queue.time_until_processing
  end

  test "should calculate processing duration" do
    @publishing_queue.attempted_at = 5.minutes.ago
    @publishing_queue.completed_at = Time.current
    
    duration = @publishing_queue.processing_duration
    assert duration > 250  # Should be around 300 seconds (5 minutes)
    assert duration < 350
  end

  test "should calculate next retry time with exponential backoff" do
    @publishing_queue.processing_status = 'failed'
    @publishing_queue.attempted_at = Time.current
    
    # First retry: 1 minute
    @publishing_queue.retry_count = 0
    next_retry = @publishing_queue.next_retry_at
    expected_time = @publishing_queue.attempted_at + 1.minute
    assert_in_delta expected_time.to_f, next_retry.to_f, 1.0
    
    # Second retry: 5 minutes
    @publishing_queue.retry_count = 1
    next_retry = @publishing_queue.next_retry_at
    expected_time = @publishing_queue.attempted_at + 5.minutes
    assert_in_delta expected_time.to_f, next_retry.to_f, 1.0
  end

  test "should determine if should retry now" do
    @publishing_queue.processing_status = 'failed'
    @publishing_queue.retry_count = 1
    @publishing_queue.attempted_at = 10.minutes.ago
    
    assert @publishing_queue.should_retry_now?
    
    @publishing_queue.attempted_at = 1.minute.ago
    assert_not @publishing_queue.should_retry_now?
  end

  test "should retry processing when eligible" do
    @publishing_queue.processing_status = 'failed'
    @publishing_queue.retry_count = 1
    @publishing_queue.save!
    
    assert @publishing_queue.may_retry_processing?
    @publishing_queue.retry_processing!
    
    assert_equal 'pending', @publishing_queue.processing_status
    assert_not_nil @publishing_queue.processing_metadata['retry_attempted_at']
  end

  test "should pause and resume processing" do
    @publishing_queue.save!
    
    assert @publishing_queue.may_pause_processing?
    @publishing_queue.pause_processing!
    assert_equal 'paused', @publishing_queue.processing_status
    
    assert @publishing_queue.may_resume_processing?
    @publishing_queue.resume_processing!
    assert_equal 'pending', @publishing_queue.processing_status
  end

  test "should cancel processing" do
    @publishing_queue.save!
    
    assert @publishing_queue.may_cancel_processing?
    @publishing_queue.cancel_processing!
    assert_equal 'cancelled', @publishing_queue.processing_status
  end

  test "should update processing metadata" do
    @publishing_queue.save!
    
    @publishing_queue.update_processing_metadata('test_key', 'test_value')
    assert_equal 'test_value', @publishing_queue.processing_metadata['test_key']
  end

  test "should add processing logs" do
    @publishing_queue.save!
    
    @publishing_queue.add_processing_log('Test message', level: 'info')
    logs = @publishing_queue.processing_logs
    
    assert_equal 1, logs.length
    assert_equal 'Test message', logs.first['message']
    assert_equal 'info', logs.first['level']
    assert_not_nil logs.first['timestamp']
  end

  test "should limit processing logs to 50 entries" do
    @publishing_queue.save!
    
    # Add 55 log entries
    55.times do |i|
      @publishing_queue.add_processing_log("Message #{i}")
    end
    
    logs = @publishing_queue.processing_logs
    assert_equal 50, logs.length
    assert_equal 'Message 54', logs.last['message']
  end

  test "should get latest log" do
    @publishing_queue.save!
    
    @publishing_queue.add_processing_log('First message')
    @publishing_queue.add_processing_log('Latest message')
    
    latest = @publishing_queue.latest_log
    assert_equal 'Latest message', latest['message']
  end

  test "should return processing summary" do
    @publishing_queue.processing_status = 'failed'
    @publishing_queue.retry_count = 2
    @publishing_queue.error_message = 'Test error'
    @publishing_queue.attempted_at = 1.hour.ago
    @publishing_queue.save!
    
    summary = @publishing_queue.processing_summary
    
    assert_equal 'failed', summary[:status]
    assert_equal 2, summary[:retry_count]
    assert_equal 1, summary[:retries_remaining]
    assert_equal 'Test error', summary[:failure_reason]
    assert_not_nil summary[:next_retry_at]
  end

  test "should get failure reason" do
    @publishing_queue.error_message = 'Specific error'
    assert_equal 'Specific error', @publishing_queue.failure_reason
    
    @publishing_queue.error_message = nil
    @publishing_queue.processing_metadata = { 'last_error' => 'Metadata error' }
    assert_equal 'Metadata error', @publishing_queue.failure_reason
    
    @publishing_queue.processing_metadata = {}
    assert_equal 'Unknown error', @publishing_queue.failure_reason
  end

  test "should process ready items" do
    # Create ready items
    ready_item = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 5.minutes.ago,
      processing_status: 'pending'
    )
    
    results = PublishingQueue.process_ready_items(5)
    assert results.is_a?(Array)
    assert results.length >= 1
    
    # Check that the item was processed
    ready_item.reload
    assert_equal 'processing', ready_item.processing_status
  end

  test "should calculate batch statistics" do
    batch_id = 'test_batch_123'
    
    # Create items with same batch_id
    3.times do |i|
      PublishingQueue.create!(
        content_schedule: @content_schedule,
        scheduled_for: 1.hour.ago,
        batch_id: batch_id,
        processing_status: ['pending', 'completed', 'failed'][i]
      )
    end
    
    stats = PublishingQueue.batch_statistics(batch_id)
    
    assert_equal 3, stats[:total]
    assert_equal 1, stats[:pending]
    assert_equal 1, stats[:completed]
    assert_equal 1, stats[:failed]
    assert stats.key?(:success_rate)
  end

  test "should calculate processing statistics" do
    # Create items within time range
    PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.ago,
      processing_status: 'completed',
      created_at: 12.hours.ago
    )
    
    stats = PublishingQueue.processing_statistics(24.hours)
    
    assert stats.key?(:total_processed)
    assert stats.key?(:completed)
    assert stats.key?(:failed)
    assert stats.key?(:success_rate)
    assert stats.key?(:average_processing_time)
  end
end