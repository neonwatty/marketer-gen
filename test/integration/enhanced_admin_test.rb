require 'test_helper'

class EnhancedAdminTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = User.create!(
      email_address: "admin_test@example.com",
      password: "password123",
      role: "admin",
      full_name: "Admin Test User"
    )
    
    @regular_user = User.create!(
      email_address: "regular_test@example.com",
      password: "password123",
      role: "marketer",
      full_name: "Regular Test User"
    )
    
    # Create some test data
    @old_activity = Activity.create!(
      user: @regular_user,
      action: "test_action",
      controller: "test",
      ip_address: "192.168.1.1",
      occurred_at: 31.days.ago,
      response_status: 200
    )
    
    @expired_session = Session.create!(
      user: @regular_user,
      expires_at: 1.day.ago,
      user_agent: "Test Browser"
    )
    
    @old_audit_log = AdminAuditLog.create!(
      user: @admin_user,
      action: "test_audit",
      created_at: 91.days.ago
    )
  end

  test "admin can access system maintenance page" do
    sign_in_as(@admin_user)
    
    get "/admin/system_maintenance"
    assert_response :success
    
    assert_select "h1", text: /System Maintenance/
    assert_select ".panel-title", text: "Database Cleanup Statistics"
  end

  test "non-admin cannot access system maintenance" do
    sign_in_as(@regular_user)
    
    get "/admin/system_maintenance"
    assert_response :redirect
  end

  test "admin can perform cleanup operations via system maintenance" do
    sign_in_as(@admin_user)
    
    # Test old activities cleanup
    assert_difference('Activity.count', -1) do
      post "/admin/system_maintenance", params: { maintenance_action: 'cleanup_old_activities' }
    end
    
    assert_redirected_to "/admin"
    follow_redirect!
    assert_select ".alert-success", text: /Deleted 1 old activity records/
  end

  test "admin can perform expired sessions cleanup" do
    sign_in_as(@admin_user)
    
    assert_difference('Session.count', -1) do
      post "/admin/system_maintenance", params: { maintenance_action: 'cleanup_expired_sessions' }
    end
    
    assert_redirected_to "/admin"
    follow_redirect!
    assert_select ".alert-success", text: /Deleted 1 expired sessions/
  end

  test "admin can perform full cleanup" do
    sign_in_as(@admin_user)
    
    assert_difference('Activity.count + Session.count + AdminAuditLog.count', -3) do
      post "/admin/system_maintenance", params: { maintenance_action: 'full_cleanup' }
    end
    
    assert_redirected_to "/admin"
    follow_redirect!
    assert_select ".alert-success", text: /Cleanup complete/
  end

  test "system maintenance logs admin actions" do
    sign_in_as(@admin_user)
    
    assert_difference('AdminAuditLog.count', 1) do
      post "/admin/system_maintenance", params: { maintenance_action: 'cleanup_old_activities' }
    end
    
    audit_log = AdminAuditLog.last
    assert_equal @admin_user, audit_log.user
    assert_equal "system_maintenance", audit_log.action
    assert_includes audit_log.change_details, "cleanup_old_activities"
  end

  test "admin can access bulk unlock action for users" do
    # Create locked users
    locked_user1 = User.create!(
      email_address: "locked1@example.com",
      password: "password123",
      role: :marketer,
      locked_at: 1.hour.ago,
      lock_reason: "Test lock"
    )
    
    locked_user2 = User.create!(
      email_address: "locked2@example.com", 
      password: "password123",
      role: :marketer,
      locked_at: 2.hours.ago,
      lock_reason: "Test lock"
    )
    
    sign_in_as(@admin_user)
    
    post "/admin/user/bulk_unlock", params: { 
      bulk_ids: [locked_user1.id, locked_user2.id] 
    }
    
    assert_redirected_to "/admin/user"
    follow_redirect!
    assert_select ".alert-success", text: /Successfully unlocked 2 user/
    
    # Verify users are unlocked
    assert_nil locked_user1.reload.locked_at
    assert_nil locked_user2.reload.locked_at
  end

  test "enhanced user list view has proper filtering and search" do
    sign_in_as(@admin_user)
    
    get "/admin/user"
    assert_response :success
    
    # Check for filter options
    assert_select "select[name*='role']"
    assert_select "input[name*='email_address']"
    assert_select "input[name*='full_name']"
    
    # Check for sortable columns
    assert_select "th a", text: /Email/
    assert_select "th a", text: /Full Name/
    assert_select "th a", text: /Role/
  end

  test "enhanced activity view has proper filtering" do
    sign_in_as(@admin_user)
    
    get "/admin/activity"
    assert_response :success
    
    # Check for filter options
    assert_select "select[name*='suspicious']"
    assert_select "input[name*='ip_address']"
    assert_select "input[name*='action']"
    assert_select "input[name*='controller']"
    
    # Check for sortable columns
    assert_select "th a", text: /Action/
    assert_select "th a", text: /IP Address/
    assert_select "th a", text: /Occurred At/
  end

  test "admin dashboard shows system health status" do
    sign_in_as(@admin_user)
    
    get "/admin"
    assert_response :success
    
    # Check for system health indicator
    assert_select ".label", text: /System/
    
    # Check for quick actions panel
    assert_select ".panel-title", text: /Quick Actions/
    assert_select "a[href*='system_maintenance']", text: /System Maintenance/
    assert_select "a[href*='user']", text: /Manage Users/
    assert_select "a[href*='activity']", text: /View Activities/
    assert_select "a[href*='admin_audit_log']", text: /Audit Logs/
  end

  test "admin dashboard shows comprehensive statistics" do
    sign_in_as(@admin_user)
    
    get "/admin"
    assert_response :success
    
    # Check for user statistics panels
    assert_select ".panel-title", text: /Total Users/
    assert_select ".panel-title", text: /Active Users/
    assert_select ".panel-title", text: /Locked Users/
    assert_select ".panel-title", text: /Suspended Users/
    
    # Check for activity statistics
    assert_select ".panel-title", text: /Activities Today/
    assert_select ".panel-title", text: /Suspicious Activities/
    assert_select ".panel-title", text: /Active Sessions/
    
    # Check for recent data tables
    assert_select ".panel-title", text: /Recent Admin Actions/
    assert_select ".panel-title", text: /Recent Registrations/
    
    # Check for system metrics
    assert_select ".panel-title", text: /System Metrics/
  end

  test "rails admin enforces admin-only access" do
    sign_in_as(@regular_user)
    
    get "/admin"
    assert_response :redirect
    
    get "/admin/user"
    assert_response :redirect
    
    get "/admin/activity"
    assert_response :redirect
  end

  test "audit logs are created for admin actions" do
    sign_in_as(@admin_user)
    
    # Test user suspension creates audit log
    assert_difference('AdminAuditLog.count', 1) do
      post "/admin/user/#{@regular_user.id}/suspend", params: { 
        suspension_reason: "Test suspension" 
      }
    end
    
    audit_log = AdminAuditLog.last
    assert_equal @admin_user, audit_log.user
    assert_equal "suspended_user", audit_log.action
    assert_equal @regular_user, audit_log.auditable
  end

  private

  def sign_in_as(user)
    post session_path, params: { 
      email_address: user.email_address, 
      password: "password123" 
    }
  end
end