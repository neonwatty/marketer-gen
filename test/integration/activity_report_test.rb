require "test_helper"

class ActivityReportTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "report_user@example.com",
      password: "password123",
      role: "marketer"
    )
    
    # Create diverse test activities for reporting
    @activities_data = [
      {
        controller: "profiles", action: "show", request_path: "/profile",
        response_status: 200, response_time: 25, device_type: "desktop",
        browser_name: "Chrome", occurred_at: 2.days.ago
      },
      {
        controller: "profiles", action: "update", request_path: "/profile",
        response_status: 200, response_time: 150, device_type: "mobile",
        browser_name: "Safari", occurred_at: 1.day.ago
      },
      {
        controller: "activities", action: "index", request_path: "/activities",
        response_status: 200, response_time: 35, device_type: "desktop",
        browser_name: "Firefox", occurred_at: 6.hours.ago
      },
      {
        controller: "home", action: "index", request_path: "/",
        response_status: 500, response_time: 0, device_type: "desktop",
        browser_name: "Chrome", occurred_at: 3.hours.ago
      },
      {
        controller: "sessions", action: "create", request_path: "/session",
        response_status: 302, response_time: 45, device_type: "tablet",
        browser_name: "Safari", suspicious: true, occurred_at: 1.hour.ago
      }
    ]
    
    @activities_data.each_with_index do |data, index|
      Activity.create!(
        user: @user,
        controller: data[:controller],
        action: data[:action],
        request_path: data[:request_path],
        request_method: "GET",
        response_status: data[:response_status],
        response_time: data[:response_time],
        ip_address: "192.168.1.#{100 + index}",
        device_type: data[:device_type],
        browser_name: data[:browser_name],
        os_name: "macOS",
        suspicious: data.fetch(:suspicious, false),
        occurred_at: data[:occurred_at]
      )
    end
  end

  test "activity report page loads successfully for authenticated user" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    assert_select "h1", "Activity Report"
  end

  test "activity report page redirects unauthenticated users" do
    get activity_report_path
    assert_redirected_to new_session_path
  end

  test "activity report displays summary statistics" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check summary cards
    assert_select ".grid" do
      # Total Activities card
      assert_select "h3", "Total Activities"
      assert_select "p", "5" # Total count
      
      # Unique IPs card
      assert_select "h3", "Unique IPs"
      assert_select "p", "5" # Each activity has different IP
      
      # Failed Requests card
      assert_select "h3", "Failed Requests"
      assert_select "p", "1" # One 500 error
      
      # Suspicious Activities card
      assert_select "h3", "Suspicious Activities"
      assert_select "p", "1" # One suspicious activity
    end
  end

  test "activity report shows top activities breakdown" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check top activities section
    assert_select "h2", "Top Activities"
    assert_select "span", /profiles#show/
    assert_select "span", /profiles#update/
    assert_select "span", /activities#index/
  end

  test "activity report displays device usage information" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check device usage section
    assert_select "h2", "Device Usage"
    assert_select "h3", "Devices"
    assert_select "span", "desktop"
    assert_select "span", "mobile"
    assert_select "span", "tablet"
    
    assert_select "h3", "Browsers"
    assert_select "span", "Chrome"
    assert_select "span", "Safari"
    assert_select "span", "Firefox"
  end

  test "activity report shows performance metrics" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check performance metrics section
    assert_select "h2", "Performance Metrics"
    assert_select "dt", "Average:"
    assert_select "dt", "Median:"
    
    # Check slowest actions table
    assert_select "h3", "Slowest Actions"
    assert_select "table" do
      assert_select "th", "Action"
      assert_select "th", "Time"
      assert_select "th", "Path"
    end
  end

  test "activity report displays access patterns" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check access patterns section
    assert_select "h2", "Access Patterns"
    assert_select "h3", "Activity by Hour"
    assert_select "h3", "Top Resources"
    assert_select "span", "/profile"
    assert_select "span", "/activities"
  end

  test "activity report includes export functionality" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check export link is present
    assert_select "a", "Export CSV"
    
    # Verify the export link has correct parameters
    export_link = css_select("a:contains('Export CSV')").first
    href = export_link["href"]
    assert_includes href, "export_activity_report_path"
    assert_includes href, "format=csv"
  end

  test "activity report includes view activities link" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check view activities link
    assert_select "a[href='#{activities_path}']", "View Activities"
  end

  test "activity report shows security alerts when present" do
    # Create additional suspicious activities to trigger alerts
    3.times do |i|
      Activity.create!(
        user: @user,
        controller: "sessions",
        action: "create",
        request_path: "/session",
        request_method: "POST",
        response_status: 401,
        response_time: 10,
        ip_address: "10.0.0.#{i + 1}",
        device_type: "desktop",
        browser_name: "Chrome",
        os_name: "macOS",
        suspicious: true,
        occurred_at: 1.hour.ago
      )
    end
    
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Should show security alerts section
    assert_select "h2", "Security Alerts"
    assert_select "h3", "Recommendations"
  end

  test "activity report filters by date range" do
    sign_in_as(@user)
    
    # Filter for activities from the last day
    start_date = 1.day.ago.to_date
    end_date = Date.current
    
    get activity_report_path, params: {
      start_date: start_date,
      end_date: end_date
    }
    assert_response :success
    
    # Should show filtered results
    assert_select "input[name='start_date'][value='#{start_date}']"
    assert_select "input[name='end_date'][value='#{end_date}']"
  end

  test "activity report includes date filter form" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Check date filter form
    assert_select "form[action='#{activity_report_path}']" do
      assert_select "input[name='start_date'][type='date']"
      assert_select "input[name='end_date'][type='date']"
      assert_select "input[type='submit'][value='Generate Report']"
    end
  end

  test "activity report handles empty data gracefully" do
    # Create user with no activities
    empty_user = User.create!(
      email_address: "empty_report@example.com",
      password: "password123",
      role: "marketer"
    )
    
    sign_in_as(empty_user)
    
    get activity_report_path
    assert_response :success
    
    # Should show zero statistics
    assert_select "p", "0"
  end

  test "activity report shows correct percentage calculations" do
    sign_in_as(@user)
    
    get activity_report_path
    assert_response :success
    
    # Failed requests percentage should be calculated correctly
    # 1 failed out of 5 total = 20%
    assert_select "p", "20.0%"
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end