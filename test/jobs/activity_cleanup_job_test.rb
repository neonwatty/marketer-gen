require "test_helper"

class ActivityCleanupJobTest < ActiveJob::TestCase
  setup do
    @user = users(:regular)
    
    # Create activities of various ages
    create_aged_activities
  end
  
  test "removes activities older than retention period" do
    # Set retention to 30 days for testing
    Rails.application.config.activity_tracking.retention_days = 30
    
    assert_difference 'Activity.count', -3 do
      ActivityCleanupJob.perform_now
    end
    
    # Verify only old non-suspicious activities were deleted
    assert Activity.where("occurred_at < ?", 30.days.ago).where(suspicious: false).empty?
    
    # Verify recent activities remain
    assert Activity.where("occurred_at > ?", 30.days.ago).any?
    
    # Verify old suspicious activities remain
    assert Activity.where("occurred_at < ?", 30.days.ago).where(suspicious: true).any?
  end
  
  test "handles large datasets in batches" do
    # Create many old activities
    1500.times do
      Activity.create!(
        user: @user,
        controller: "test",
        action: "batch",
        occurred_at: 100.days.ago
      )
    end
    
    Rails.application.config.activity_tracking.retention_days = 90
    
    assert_difference 'Activity.count', -1503 do
      ActivityCleanupJob.perform_now
    end
  end
  
  test "cleans up user activities if model exists" do
    # Create old user activities
    if defined?(UserActivity)
      3.times do
        UserActivity.create!(
          user: @user,
          action: "test",
          performed_at: 100.days.ago
        )
      end
      
      assert_difference 'UserActivity.count', -3 do
        ActivityCleanupJob.perform_now
      end
    end
  end
  
  test "logs cleanup operations" do
    Rails.application.config.activity_tracking.retention_days = 30
    
    # Expect logging
    ActivityLogger.expects(:log).with(:info, "Starting activity cleanup", anything).once
    ActivityLogger.expects(:log).with(:info, "Activity cleanup completed", anything).once
    
    ActivityCleanupJob.perform_now
  end
  
  test "handles database errors gracefully" do
    # Mock database error during optimization
    ActiveRecord::Base.connection.stubs(:execute).raises(StandardError.new("DB Error"))
    
    # Should not raise error
    assert_nothing_raised do
      ActivityCleanupJob.perform_now
    end
  end
  
  test "uses default retention period if not configured" do
    # Remove configuration
    Rails.application.config.activity_tracking.retention_days = nil
    
    # Should use 90 days default
    assert_difference 'Activity.count', -3 do
      ActivityCleanupJob.perform_now
    end
    
    # Verify activities older than 90 days were deleted
    assert Activity.where("occurred_at < ?", 90.days.ago).where(suspicious: false).empty?
  end
  
  private
  
  def create_aged_activities
    # Recent activities (should be kept)
    2.times do |i|
      Activity.create!(
        user: @user,
        controller: "recent",
        action: "test",
        occurred_at: i.days.ago
      )
    end
    
    # Old activities (should be deleted)
    3.times do |i|
      Activity.create!(
        user: @user,
        controller: "old",
        action: "test",
        occurred_at: (91 + i).days.ago
      )
    end
    
    # Old suspicious activity (should be kept)
    Activity.create!(
      user: @user,
      controller: "suspicious",
      action: "test",
      suspicious: true,
      occurred_at: 100.days.ago
    )
  end
end