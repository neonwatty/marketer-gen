require "test_helper"

class PublishingQueueServiceTest < ActiveSupport::TestCase
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
    
    @publishing_queue = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 5.minutes.ago,
      processing_status: 'pending'
    )
    
    @service = PublishingQueueService.new
  end

  test "should initialize with default values" do
    service = PublishingQueueService.new
    assert_equal 10, service.processing_limit
    assert_equal 3, service.retry_limit
    assert_equal 5, service.batch_size
  end

  test "should initialize with custom values" do
    service = PublishingQueueService.new(
      processing_limit: 20,
      retry_limit: 5,
      batch_size: 10
    )
    assert_equal 20, service.processing_limit
    assert_equal 5, service.retry_limit
    assert_equal 10, service.batch_size
  end

  test "should process ready items" do
    # Create another ready item
    PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 10.minutes.ago,
      processing_status: 'pending'
    )
    
    results = @service.process_ready_items
    
    assert results.is_a?(Hash)
    assert results.key?(:processed)
    assert results.key?(:successful)
    assert results.key?(:failed)
    assert results.key?(:retried)
    assert results.key?(:errors)
    
    assert results[:processed] >= 2
  end

  test "should handle processing errors gracefully" do
    # Mock a failure scenario by stubbing the queue processing
    PublishingQueue.stub :process_ready_items, -> (_limit) { raise StandardError.new("Test error") } do
      results = @service.process_ready_items
      
      assert results.key?(:errors)
      assert results[:errors].any? { |error| error.key?(:system_error) }
    end
  end

  test "should process campaign items" do
    campaign_queue = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 5.minutes.ago,
      processing_status: 'pending'
    )
    
    results = @service.process_campaign_items(@campaign.id)
    
    assert results.is_a?(Hash)
    assert results.key?(:processed)
    assert results.key?(:successful)
    assert results.key?(:failed)
    assert results[:processed] >= 1
  end

  test "should process platform items" do
    # Create items for specific platform
    twitter_queue = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 5.minutes.ago,
      processing_status: 'pending'
    )
    
    results = @service.process_platform_items('twitter')
    
    assert results.is_a?(Hash)
    assert results.key?(:processed)
    assert results.key?(:successful)
    assert results.key?(:failed)
    assert results[:processed] >= 1
  end

  test "should process priority items" do
    # Create high priority schedule
    high_priority_schedule = ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 2,
      platform: 'twitter',
      channel: 'social_media',
      scheduled_at: 1.hour.from_now,
      priority: 5  # High priority
    )
    
    priority_queue = PublishingQueue.create!(
      content_schedule: high_priority_schedule,
      scheduled_for: 5.minutes.ago,
      processing_status: 'pending'
    )
    
    results = @service.process_priority_items
    
    assert results.is_a?(Hash)
    assert results.key?(:processed)
    assert results.key?(:successful)
    assert results.key?(:failed)
  end

  test "should get processing statistics" do
    # Create some completed and failed items
    PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.ago,
      processing_status: 'completed',
      created_at: 12.hours.ago
    )
    
    stats = @service.processing_statistics(24.hours)
    
    assert stats.is_a?(Hash)
    assert stats.key?(:total_processed)
    assert stats.key?(:completed)
    assert stats.key?(:failed)
    assert stats.key?(:success_rate)
    assert stats.key?(:average_processing_time)
  end

  test "should get queue health metrics" do
    # Create items with different statuses
    PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 2.hours.ago,
      processing_status: 'pending'  # Overdue
    )
    
    PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 1.hour.ago,
      processing_status: 'failed'
    )
    
    health = @service.queue_health
    
    assert health.is_a?(Hash)
    assert health.key?(:status)
    assert health.key?(:score)
    assert health.key?(:metrics)
    assert health.key?(:recommendations)
    
    assert %w[excellent good fair poor critical].include?(health[:status])
    assert health[:score] >= 0 && health[:score] <= 100
    
    metrics = health[:metrics]
    assert metrics.key?(:pending_items)
    assert metrics.key?(:overdue_items)
    assert metrics.key?(:failed_items)
    assert metrics.key?(:success_rate)
  end

  test "should cleanup old records" do
    # Create old completed record
    old_queue = PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 10.days.ago,
      processing_status: 'completed',
      completed_at: 10.days.ago
    )
    
    deleted_count = @service.cleanup_old_records(7)
    
    assert deleted_count >= 1
    assert_raises(ActiveRecord::RecordNotFound) do
      old_queue.reload
    end
  end

  test "should pause processing" do
    @service.pause_processing
    
    @publishing_queue.reload
    assert_equal 'paused', @publishing_queue.processing_status
  end

  test "should resume processing" do
    @publishing_queue.update!(processing_status: 'paused')
    
    @service.resume_processing
    
    @publishing_queue.reload
    assert_equal 'pending', @publishing_queue.processing_status
  end

  test "should cancel schedule items" do
    cancelled_count = @service.cancel_schedule_items(@content_schedule.id)
    
    assert cancelled_count >= 1
    @publishing_queue.reload
    assert_equal 'cancelled', @publishing_queue.processing_status
  end

  test "should reschedule items" do
    new_time = 2.hours.from_now
    updated_count = @service.reschedule_items([@publishing_queue.id], new_time)
    
    assert updated_count >= 1
    @publishing_queue.reload
    assert_in_delta new_time.to_f, @publishing_queue.scheduled_for.to_f, 60.0
    assert_equal 'scheduled', @publishing_queue.processing_status
  end

  test "should force retry items" do
    @publishing_queue.update!(
      processing_status: 'failed',
      retry_count: 1
    )
    
    results = @service.force_retry_items([@publishing_queue.id])
    
    assert results.key?(:retried)
    assert results.key?(:errors)
    assert results[:retried] >= 1
    
    @publishing_queue.reload
    assert_equal 'pending', @publishing_queue.processing_status
  end

  test "should handle bulk batch processing" do
    batch_id = 'test_batch_123'
    @publishing_queue.update!(batch_id: batch_id)
    
    results = @service.bulk_process_by_batch(batch_id)
    
    assert results.is_a?(Hash)
    assert results.key?(:processed)
    assert results.key?(:successful)
    assert results.key?(:failed)
  end

  test "should calculate health score correctly" do
    # Test with good metrics
    score = @service.send(:calculate_health_score, 0, 0, 0, 95.0)
    assert score > 90
    
    # Test with poor metrics
    score = @service.send(:calculate_health_score, 200, 50, 100, 60.0)
    assert score < 50
  end

  test "should determine health status correctly" do
    assert_equal 'excellent', @service.send(:determine_health_status, 95)
    assert_equal 'good', @service.send(:determine_health_status, 80)
    assert_equal 'fair', @service.send(:determine_health_status, 60)
    assert_equal 'poor', @service.send(:determine_health_status, 35)
    assert_equal 'critical', @service.send(:determine_health_status, 15)
  end

  test "should generate health recommendations" do
    recommendations = @service.send(:generate_health_recommendations, 150, 25, 50, 70.0)
    
    assert recommendations.is_a?(Array)
    assert recommendations.any? { |r| r.include?('overdue') }
    assert recommendations.any? { |r| r.include?('failed') }
    assert recommendations.any? { |r| r.include?('success rate') }
    assert recommendations.any? { |r| r.include?('backlog') }
  end

  test "should calculate recent success rate" do
    # Create items within last 24 hours
    PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 12.hours.ago,
      processing_status: 'completed',
      created_at: 12.hours.ago
    )
    
    PublishingQueue.create!(
      content_schedule: @content_schedule,
      scheduled_for: 6.hours.ago,
      processing_status: 'failed',
      created_at: 6.hours.ago
    )
    
    success_rate = @service.send(:calculate_recent_success_rate)
    
    assert success_rate >= 0.0
    assert success_rate <= 100.0
  end

  test "should get platform publisher correctly" do
    twitter_publisher = @service.send(:get_platform_publisher, 'twitter')
    assert twitter_publisher.is_a?(PublishingQueueService::TwitterPublisher)
    
    instagram_publisher = @service.send(:get_platform_publisher, 'instagram')
    assert instagram_publisher.is_a?(PublishingQueueService::InstagramPublisher)
    
    unknown_publisher = @service.send(:get_platform_publisher, 'unknown')
    assert_nil unknown_publisher
  end

  test "should process single item successfully" do
    @publishing_queue.update!(processing_status: 'processing')
    
    result = @service.send(:process_single_item, @publishing_queue)
    
    assert result.is_a?(Hash)
    assert result.key?(:success)
    
    @publishing_queue.reload
    if result[:success]
      assert_equal 'completed', @publishing_queue.processing_status
    else
      assert_equal 'failed', @publishing_queue.processing_status
    end
  end

  test "should handle unsupported platform" do
    unsupported_schedule = ContentSchedule.create!(
      campaign: @campaign,
      content_item_type: 'ContentAsset',
      content_item_id: 3,
      platform: 'unsupported',
      channel: 'social_media',
      scheduled_at: 1.hour.from_now,
      priority: 3
    )
    
    unsupported_queue = PublishingQueue.create!(
      content_schedule: unsupported_schedule,
      scheduled_for: 5.minutes.ago,
      processing_status: 'processing'
    )
    
    result = @service.send(:process_single_item, unsupported_queue)
    
    assert_equal false, result[:success]
    assert result[:error].include?('No publisher available')
  end
end