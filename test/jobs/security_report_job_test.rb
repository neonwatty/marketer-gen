require "test_helper"

class SecurityReportJobTest < ActiveJob::TestCase
  test "generates security report successfully" do
    assert_nothing_raised do
      SecurityReportJob.perform_now(24.hours)
    end
    
    # Check report was cached
    cache_key = "security_report:#{Date.current.strftime('%Y-%m-%d')}"
    cached_report = Rails.cache.read(cache_key)
    assert cached_report.present?
    assert cached_report.key?(:period)
    assert cached_report.key?(:total_alerts)
  end

  test "schedules next report job" do
    assert_enqueued_jobs 1 do
      SecurityReportJob.perform_now(24.hours)
    end
  end

  test "job is properly configured" do
    job = SecurityReportJob.new
    assert_equal "security", job.queue_name
  end

  test "caches report with correct key format" do
    SecurityReportJob.perform_now(24.hours)
    
    expected_key = "security_report:#{Date.current.strftime('%Y-%m-%d')}"
    cached_data = Rails.cache.read(expected_key)
    assert cached_data.present?
  end

  test "accepts custom report period" do
    assert_nothing_raised do
      SecurityReportJob.perform_now(12.hours)
    end
  end
end