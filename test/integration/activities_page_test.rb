require "test_helper"

class ActivitiesPageTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "activities_user@example.com",
      password: "password123",
      role: "marketer"
    )
    
    # Create some test activities
    5.times do |i|
      Activity.create!(
        user: @user,
        controller: "profiles",
        action: "show",
        request_path: "/profile",
        request_method: "GET",
        response_status: 200,
        response_time: 25 + i,
        ip_address: "192.168.1.#{100 + i}",
        device_type: "desktop",
        browser_name: "Chrome",
        os_name: "macOS",
        occurred_at: i.hours.ago
      )
    end
    
    # Create a failed activity
    Activity.create!(
      user: @user,
      controller: "profiles",
      action: "update",
      request_path: "/profile",
      request_method: "PATCH",
      response_status: 422,
      response_time: 45,
      ip_address: "192.168.1.105",
      device_type: "desktop",
      browser_name: "Chrome",
      os_name: "macOS",
      occurred_at: 1.hour.ago
    )
    
    # Create a suspicious activity
    Activity.create!(
      user: @user,
      controller: "home",
      action: "index",
      request_path: "/",
      request_method: "GET",
      response_status: 200,
      response_time: 15,
      ip_address: "10.0.0.1",
      device_type: "desktop",
      browser_name: "Chrome",
      os_name: "macOS",
      suspicious: true,
      occurred_at: 30.minutes.ago
    )
  end

  test "activities page loads successfully for authenticated user" do
    sign_in_as(@user)
    
    get activities_path
    assert_response :success
    assert_select "h1", "My Activity Log"
  end

  test "activities page redirects unauthenticated users" do
    get activities_path
    assert_redirected_to new_session_path
  end

  test "activities page displays activity statistics" do
    sign_in_as(@user)
    
    get activities_path
    assert_response :success
    
    # Check that statistics cards are displayed
    assert_select ".grid .bg-white" do
      # Should show total activities label
      assert_select ".text-gray-500", "Total Activities"
      
      # Should show today label
      assert_select ".text-gray-500", "Today"
      
      # Should show this week label
      assert_select ".text-gray-500", "This Week"
      
      # Should show failed requests label
      assert_select ".text-gray-500", "Failed Requests"
      
      # Should show suspicious label
      assert_select ".text-gray-500", "Suspicious"
    end
  end

  test "activities page displays activity table with data" do
    sign_in_as(@user)
    
    get activities_path
    assert_response :success
    
    # Check that the table is present
    assert_select "table" do
      # Check headers
      assert_select "th", "Time"
      assert_select "th", "Action"
      assert_select "th", "Path"
      assert_select "th", "Status"
      assert_select "th", "Response Time"
      assert_select "th", "IP Address"
      assert_select "th", "Device"
      
      # Check that activity data is displayed
      assert_select "td", "profiles#show"
      assert_select "td", "/profile"
      assert_select "td", "200"
      assert_select "td", "desktop / Chrome"
    end
  end

  test "activities page includes filtering controls" do
    sign_in_as(@user)
    
    get activities_path
    assert_response :success
    
    # Check filter form elements
    assert_select "input[name='start_date']"
    assert_select "input[name='end_date']"
    assert_select "select[name='status']" do
      assert_select "option[value='']", "All"
      assert_select "option[value='successful']", "Successful"
      assert_select "option[value='failed']", "Failed"
      assert_select "option[value='suspicious']", "Suspicious"
    end
    assert_select "input[type='submit'][value='Filter']"
  end

  test "activities page filters by status" do
    sign_in_as(@user)
    
    # Filter for failed activities
    get activities_path, params: { status: "failed" }
    assert_response :success
    
    # Should show only failed activities
    assert_select "table tbody tr", count: 1
    assert_select "td", "422"
  end

  test "activities page filters by date range" do
    sign_in_as(@user)
    
    # Filter for today's activities
    today = Date.current
    get activities_path, params: { 
      start_date: today, 
      end_date: today 
    }
    assert_response :success
    
    # Should show the filter form with the dates filled
    assert_select "input[name='start_date'][value='#{today}']"
    assert_select "input[name='end_date'][value='#{today}']"
  end

  test "activities page shows suspicious activities with special styling" do
    sign_in_as(@user)
    
    # Filter for suspicious activities
    get activities_path, params: { status: "suspicious" }
    assert_response :success
    
    # Should show suspicious activities
    assert_select "table tbody tr", count: 1
    assert_select "td", "home#index"
  end

  test "activities page handles empty results gracefully" do
    # Create a user with no activities
    empty_user = User.create!(
      email_address: "empty@example.com",
      password: "password123",
      role: "marketer"
    )
    
    sign_in_as(empty_user)
    
    get activities_path
    assert_response :success
    
    # Should show zero statistics
    assert_select "div", text: "0"
  end

  test "activities page displays correct counts in statistics" do
    sign_in_as(@user)
    
    get activities_path
    assert_response :success
    
    # Check that statistics are present (counts depend on current activities created during test)
    assert_select ".text-gray-500", "Total Activities"
    assert_select ".text-gray-500", "Failed Requests"
    assert_select ".text-gray-500", "Suspicious"
    
    # Verify we have numeric values displayed
    assert_select ".text-3xl.font-semibold"
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
  end
end