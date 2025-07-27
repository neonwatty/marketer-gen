require "test_helper"

class ActivityReportServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:regular)
    @admin = users(:admin)
    
    # Create various activities for testing
    create_test_activities
  end
  
  test "generates complete report structure" do
    report = ActivityReportService.new(@user).generate_report
    
    assert_includes report.keys, :summary
    assert_includes report.keys, :activity_breakdown
    assert_includes report.keys, :suspicious_activities
    assert_includes report.keys, :performance_metrics
    assert_includes report.keys, :security_events
    assert_includes report.keys, :access_patterns
    assert_includes report.keys, :device_usage
    assert_includes report.keys, :recommendations
  end
  
  test "calculates summary statistics correctly" do
    report = ActivityReportService.new(@user).generate_report
    summary = report[:summary]
    
    assert_equal 10, summary[:total_activities]
    assert summary[:average_daily_activities] > 0
    assert_equal 2, summary[:suspicious_count]
    assert_equal 1, summary[:failed_requests]
    assert summary[:unique_ips] >= 1
    assert summary[:unique_sessions] >= 1
  end
  
  test "breaks down activities by controller and action" do
    report = ActivityReportService.new(@user).generate_report
    breakdown = report[:activity_breakdown]
    
    assert breakdown.is_a?(Array)
    assert breakdown.any? { |item| item[:controller] == "sessions" && item[:action] == "create" }
    
    # Check percentages add up
    total_percentage = breakdown.sum { |item| item[:percentage] }
    assert_in_delta 100.0, total_percentage, 0.1
  end
  
  test "identifies suspicious activities" do
    report = ActivityReportService.new(@user).generate_report
    suspicious = report[:suspicious_activities]
    
    assert_equal 2, suspicious[:count]
    assert suspicious[:events].is_a?(Array)
    assert suspicious[:patterns].is_a?(Hash)
  end
  
  test "calculates performance metrics" do
    report = ActivityReportService.new(@user).generate_report
    metrics = report[:performance_metrics]
    
    assert metrics[:average_response_time] > 0
    assert metrics[:median_response_time] > 0
    assert metrics[:slowest_actions].is_a?(Array)
    assert metrics[:response_time_distribution].is_a?(Hash)
  end
  
  test "detects security events" do
    # Create failed login attempts
    3.times do
      Activity.create!(
        user: @user,
        controller: "sessions",
        action: "create",
        response_status: 401,
        occurred_at: 1.hour.ago
      )
    end
    
    report = ActivityReportService.new(@user).generate_report
    security_events = report[:security_events]
    
    assert security_events.any? { |event| event[:type] == "failed_login_attempts" }
  end
  
  test "analyzes access patterns" do
    report = ActivityReportService.new(@user).generate_report
    patterns = report[:access_patterns]
    
    assert patterns[:hourly_distribution].is_a?(Hash)
    assert patterns[:daily_distribution].is_a?(Hash)
    assert patterns[:top_resources].is_a?(Hash)
    assert patterns[:access_times].is_a?(Hash)
  end
  
  test "tracks device usage" do
    report = ActivityReportService.new(@user).generate_report
    devices = report[:device_usage]
    
    assert devices[:devices].is_a?(Hash)
    assert devices[:browsers].is_a?(Hash)
    assert devices[:operating_systems].is_a?(Hash)
    assert devices[:unique_user_agents] >= 1
  end
  
  test "generates recommendations based on patterns" do
    # Create suspicious patterns
    10.times do
      Activity.create!(
        user: @user,
        suspicious: true,
        occurred_at: 1.hour.ago
      )
    end
    
    report = ActivityReportService.new(@user).generate_report
    recommendations = report[:recommendations]
    
    assert recommendations.is_a?(Array)
    assert recommendations.any? { |r| r[:type] == "security" }
  end
  
  test "respects date range filters" do
    # Create old activity
    old_activity = Activity.create!(
      user: @user,
      controller: "old",
      action: "test",
      occurred_at: 60.days.ago
    )
    
    report = ActivityReportService.new(@user, start_date: 30.days.ago).generate_report
    
    # Old activity should not be included
    breakdown = report[:activity_breakdown]
    assert_not breakdown.any? { |item| item[:controller] == "old" }
  end
  
  test "handles empty activity sets gracefully" do
    user_without_activities = User.create!(
      email_address: "noactivity@example.com",
      password: "password123"
    )
    
    report = ActivityReportService.new(user_without_activities).generate_report
    
    assert_equal 0, report[:summary][:total_activities]
    assert_empty report[:activity_breakdown]
    assert_equal 0, report[:suspicious_activities][:count]
    assert_empty report[:performance_metrics]
  end
  
  test "generates daily reports for admins" do
    assert_enqueued_emails 1 do
      ActivityReportService.generate_daily_reports
    end
  end
  
  private
  
  def create_test_activities
    # Normal activities
    5.times do |i|
      Activity.create!(
        user: @user,
        controller: "users",
        action: "index",
        response_status: 200,
        response_time: 0.1 + (i * 0.05),
        ip_address: "192.168.1.#{100 + i}",
        device_type: ["desktop", "mobile"].sample,
        browser_name: ["Chrome", "Safari"].sample,
        os_name: ["macOS", "Windows"].sample,
        occurred_at: i.hours.ago
      )
    end
    
    # Suspicious activities
    2.times do |i|
      Activity.create!(
        user: @user,
        controller: "admin",
        action: "index",
        suspicious: true,
        metadata: { "suspicious_reasons" => ["suspicious_path"] },
        occurred_at: i.days.ago
      )
    end
    
    # Failed request
    Activity.create!(
      user: @user,
      controller: "users",
      action: "show",
      response_status: 404,
      occurred_at: 1.hour.ago
    )
    
    # Session activities
    2.times do
      Activity.create!(
        user: @user,
        controller: "sessions",
        action: "create",
        response_status: 302,
        occurred_at: 2.hours.ago
      )
    end
  end
end