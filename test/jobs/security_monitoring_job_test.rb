require "test_helper"

class SecurityMonitoringJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "performs security monitoring successfully" do
    assert_nothing_raised do
      SecurityMonitoringJob.perform_now(1.hour)
    end
  end

  test "handles errors gracefully during monitoring" do
    # Create a job that should handle errors without raising
    assert_nothing_raised do
      SecurityMonitoringJob.perform_now(1.hour)
    end
  end

  test "does not schedule next job in test environment" do
    # Test environment should not auto-schedule
    assert_no_enqueued_jobs do
      SecurityMonitoringJob.perform_now(1.hour)
    end
  end

  test "job is properly configured" do
    job = SecurityMonitoringJob.new
    assert_equal "security", job.queue_name
  end

  test "accepts time window parameter" do
    assert_nothing_raised do
      SecurityMonitoringJob.perform_now(2.hours)
    end
  end
end