require "test_helper"
require "ostruct"

class ActivityTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "test@example.com",
      password: "password123",
      role: "marketer"
    )
  end

  test "should create activity with required attributes" do
    activity = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      occurred_at: Time.current
    )

    assert activity.persisted?
    assert_equal @user, activity.user
    assert_equal "index", activity.action
    assert_equal "home", activity.controller
  end

  test "should require user" do
    activity = Activity.new(
      action: "index",
      controller: "home",
      occurred_at: Time.current
    )

    assert_not activity.valid?
    assert_includes activity.errors[:user], "must exist"
  end

  test "should require action" do
    activity = Activity.new(
      user: @user,
      controller: "home",
      occurred_at: Time.current
    )

    assert_not activity.valid?
    assert_includes activity.errors[:action], "can't be blank"
  end

  test "should require controller" do
    activity = Activity.new(
      user: @user,
      action: "index",
      occurred_at: Time.current
    )

    assert_not activity.valid?
    assert_includes activity.errors[:controller], "can't be blank"
  end

  test "should set occurred_at before validation if not present" do
    activity = Activity.new(
      user: @user,
      action: "index",
      controller: "home"
    )

    assert_nil activity.occurred_at
    activity.valid?
    assert_not_nil activity.occurred_at
  end

  test "should parse device type correctly" do
    assert_equal "mobile", Activity.parse_device_type("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)")
    assert_equal "tablet", Activity.parse_device_type("Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X)")
    assert_equal "desktop", Activity.parse_device_type("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    assert_nil Activity.parse_device_type(nil)
  end

  test "should parse browser name correctly" do
    assert_equal "Chrome", Activity.parse_browser_name("Mozilla/5.0 Chrome/91.0.4472.124")
    assert_equal "Safari", Activity.parse_browser_name("Mozilla/5.0 Safari/605.1.15")
    assert_equal "Firefox", Activity.parse_browser_name("Mozilla/5.0 Firefox/89.0")
    assert_nil Activity.parse_browser_name(nil)
  end

  test "should parse OS name correctly" do
    assert_equal "Windows", Activity.parse_os_name("Mozilla/5.0 (Windows NT 10.0)")
    assert_equal "macOS", Activity.parse_os_name("Mozilla/5.0 (Macintosh; Intel Mac OS X)")
    assert_equal "Android", Activity.parse_os_name("Mozilla/5.0 (Linux; Android 11)")
    assert_nil Activity.parse_os_name(nil)
  end

  test "log_activity class method creates activity with all attributes" do
    request = OpenStruct.new(
      path: "/users",
      method: "GET",
      remote_ip: "192.168.1.1",
      user_agent: "Mozilla/5.0 Chrome/91.0",
      session: OpenStruct.new(id: "abc123"),
      referrer: "http://example.com"
    )

    response = OpenStruct.new(status: 200)

    metadata = { response_time: 0.123 }

    activity = Activity.log_activity(
      user: @user,
      action: "index",
      controller: "users",
      request: request,
      response: response,
      metadata: metadata
    )

    assert activity.persisted?
    assert_equal @user, activity.user
    assert_equal "index", activity.action
    assert_equal "users", activity.controller
    assert_equal "/users", activity.request_path
    assert_equal "GET", activity.request_method
    assert_equal "192.168.1.1", activity.ip_address
    assert_equal "Mozilla/5.0 Chrome/91.0", activity.user_agent
    assert_equal "abc123", activity.session_id
    assert_equal "http://example.com", activity.referrer
    assert_equal 200, activity.response_status
    assert_equal 0.123, activity.response_time
    assert_equal metadata.stringify_keys, activity.metadata
    assert_equal "desktop", activity.device_type
    assert_equal "Chrome", activity.browser_name
  end

  test "recent scope orders by occurred_at desc" do
    old_activity = Activity.create!(
      user: @user,
      action: "old",
      controller: "test",
      occurred_at: 2.days.ago
    )

    new_activity = Activity.create!(
      user: @user,
      action: "new",
      controller: "test",
      occurred_at: 1.hour.ago
    )

    assert_equal [new_activity, old_activity], Activity.recent.to_a
  end

  test "suspicious scope filters suspicious activities" do
    normal = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      suspicious: false
    )

    suspicious = Activity.create!(
      user: @user,
      action: "hack",
      controller: "admin",
      suspicious: true
    )

    assert_includes Activity.suspicious, suspicious
    assert_not_includes Activity.suspicious, normal
  end

  test "failed_requests scope filters by response status" do
    success = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      response_status: 200
    )

    failed = Activity.create!(
      user: @user,
      action: "create",
      controller: "users",
      response_status: 422
    )

    assert_includes Activity.failed_requests, failed
    assert_not_includes Activity.failed_requests, success
  end

  test "today scope filters activities from today" do
    today = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      occurred_at: Time.current
    )

    yesterday = Activity.create!(
      user: @user,
      action: "index",
      controller: "home",
      occurred_at: 1.day.ago
    )

    assert_includes Activity.today, today
    assert_not_includes Activity.today, yesterday
  end

  test "full_action returns controller#action" do
    activity = Activity.new(
      controller: "users",
      action: "index"
    )

    assert_equal "users#index", activity.full_action
  end

  test "duration_in_ms converts response time to milliseconds" do
    activity = Activity.new(response_time: 0.123)
    assert_equal 123.0, activity.duration_in_ms

    activity_no_time = Activity.new(response_time: nil)
    assert_nil activity_no_time.duration_in_ms
  end

  test "parsed_changes returns parsed JSON metadata" do
    changes = { name: ["Old", "New"], status: ["active", "inactive"] }
    activity = Activity.create!(
      user: @user,
      action: "update",
      controller: "users",
      metadata: changes
    )

    assert_equal changes.stringify_keys, activity.metadata
  end
end