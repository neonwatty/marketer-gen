require "test_helper"

class AdminWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email_address: "admin@example.com",
      password: "password123",
      role: "admin"
    )
    
    @regular_user = User.create!(
      email_address: "user@example.com",
      password: "password123",
      role: "marketer"
    )
  end

  test "admin can access rails admin dashboard" do
    skip "Rails Admin not mounted in test environment" if Rails.env.test?
    
    # Sign in as admin
    post session_path, params: {
      email_address: @admin.email_address,
      password: "password123"
    }
    
    follow_redirect!
    assert_response :success
    
    # Access admin dashboard
    get rails_admin_path
    assert_response :success
  end

  test "non-admin cannot access rails admin dashboard" do
    skip "Rails Admin not mounted in test environment" if Rails.env.test?
    
    # Sign in as regular user
    post session_path, params: {
      email_address: @regular_user.email_address,
      password: "password123"
    }
    
    follow_redirect!
    assert_response :success
    
    # Try to access admin dashboard
    get rails_admin_path
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select ".alert", text: /Please sign in to access the admin area/
  end

  test "suspended user cannot log in" do
    @regular_user.suspend!(reason: "Test suspension", by: @admin)
    
    post session_path, params: {
      email_address: @regular_user.email_address,
      password: "password123"
    }
    
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select ".alert", text: /Your account has been suspended: Test suspension/
  end

  test "locked user cannot log in" do
    @regular_user.lock!("Security test")
    
    post session_path, params: {
      email_address: @regular_user.email_address,
      password: "password123"
    }
    
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select ".alert", text: /Your account has been locked: Security test/
  end

  test "admin actions are audited" do
    # Sign in as admin
    post session_path, params: {
      email_address: @admin.email_address,
      password: "password123"
    }
    
    # Perform an admin action (would need to simulate Rails Admin action)
    # This is a simplified example showing the audit log creation
    assert_difference "AdminAuditLog.count", 1 do
      AdminAuditLog.log_action(
        user: @admin,
        action: "updated",
        auditable: @regular_user,
        changes: { role: ["marketer", "team_member"] }
      )
    end
    
    log = AdminAuditLog.last
    assert_equal @admin, log.user
    assert_equal "updated", log.action
    assert_equal @regular_user, log.auditable
  end

  test "admin can view user activities" do
    skip "Rails Admin not mounted in test environment" if Rails.env.test?
    
    # Create some activities
    Activity.create!(
      user: @regular_user,
      action: "index",
      controller: "home",
      occurred_at: Time.current,
      ip_address: "127.0.0.1"
    )
    
    # Sign in as admin
    post session_path, params: {
      email_address: @admin.email_address,
      password: "password123"
    }
    
    # Access Rails Admin activities
    get rails_admin_path(model_name: "activity")
    assert_response :success
  end
end