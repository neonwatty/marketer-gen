require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
    
    # Create various activities for testing
    30.times do |i|
      Activity.create!(
        user: @user,
        action: ["index", "create", "update", "show"].sample,
        controller: ["home", "users", "posts"].sample,
        occurred_at: i.days.ago,
        response_status: [200, 201, 404, 500].sample,
        suspicious: i % 10 == 0,
        ip_address: "192.168.1.#{i % 5}",
        device_type: ["desktop", "mobile"].sample,
        browser_name: ["Chrome", "Safari", "Firefox"].sample
      )
    end
    
    # Sign in the user
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
  end

  test "should get index when authenticated" do
    get activities_url
    assert_response :success
    assert_select "h1", "My Activity Log"
  end

  test "should redirect to login when not authenticated" do
    delete session_path # Sign out
    
    get activities_url
    assert_redirected_to new_session_path
  end

  test "should show activity statistics" do
    get activities_url
    assert_response :success
    
    # Check for statistics
    assert_match /Total Activities/, response.body
    assert_match /Today/, response.body
    assert_match /This Week/, response.body
    assert_match /Failed Requests/, response.body
    assert_match /Suspicious/, response.body
  end

  test "should display activities table" do
    get activities_url
    assert_response :success
    
    # Check for table headers
    assert_select "th", "Time"
    assert_select "th", "Action"
    assert_select "th", "Path"
    assert_select "th", "Status"
    assert_select "th", "Response Time"
    assert_select "th", "IP Address"
    assert_select "th", "Device"
  end

  test "should filter activities by date range" do
    get activities_url, params: {
      start_date: 7.days.ago.to_date,
      end_date: Date.today
    }
    assert_response :success
    
    # Should only show activities from last 7 days
    activities = assigns(:activities)
    assert activities.all? { |a| a.occurred_at >= 7.days.ago }
  end

  test "should filter activities by status" do
    get activities_url, params: { status: "suspicious" }
    assert_response :success
    
    activities = assigns(:activities)
    assert activities.all?(&:suspicious?)
  end

  test "should filter failed requests" do
    get activities_url, params: { status: "failed" }
    assert_response :success
    
    activities = assigns(:activities)
    assert activities.all? { |a| a.response_status && a.response_status >= 400 }
  end

  test "should filter successful requests" do
    get activities_url, params: { status: "successful" }
    assert_response :success
    
    activities = assigns(:activities)
    assert activities.all? { |a| a.response_status && a.response_status < 400 }
  end

  test "should paginate activities" do
    # Create more activities to ensure pagination
    50.times do
      Activity.create!(
        user: @user,
        action: "index",
        controller: "home",
        occurred_at: Time.current
      )
    end
    
    get activities_url
    assert_response :success
    
    # Check for pagination controls
    assert_select "nav.pagination"
  end

  test "should highlight suspicious activities" do
    # Create a suspicious activity
    Activity.create!(
      user: @user,
      action: "hack",
      controller: "admin",
      suspicious: true,
      occurred_at: Time.current
    )
    
    get activities_url
    assert_response :success
    
    # Check for highlighted row
    assert_select "tr.bg-red-50"
  end

  test "should show only current user activities" do
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password123",
      role: "marketer"
    )
    
    Activity.create!(
      user: other_user,
      action: "index",
      controller: "home",
      occurred_at: Time.current
    )
    
    get activities_url
    assert_response :success
    
    activities = assigns(:activities)
    assert activities.all? { |a| a.user_id == @user.id }
  end

  test "should display activity details correctly" do
    activity = Activity.create!(
      user: @user,
      action: "create",
      controller: "posts",
      request_path: "/posts",
      response_status: 201,
      response_time: 0.123,
      ip_address: "192.168.1.100",
      device_type: "mobile",
      browser_name: "Safari",
      occurred_at: Time.current
    )
    
    get activities_url
    assert_response :success
    
    # Check for activity details in the table
    assert_match /posts#create/, response.body
    assert_match /192\.168\.1\.100/, response.body
    assert_match /mobile.*Safari/, response.body
    assert_match /123\.0 ms/, response.body
  end
end