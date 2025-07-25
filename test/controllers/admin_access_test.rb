require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
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
  end
  
  test "admin user can access admin panel" do
    # Sign in as admin
    post session_path, params: {
      email_address: @admin_user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
    follow_redirect!
    
    # Access admin panel
    get rails_admin_path
    assert_response :success
    assert_select "a", text: "Dashboard"
  end
  
  test "regular user cannot access admin panel" do
    # Sign in as regular user
    post session_path, params: {
      email_address: @regular_user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
    follow_redirect!
    
    # Try to access admin panel
    get rails_admin_path
    assert_redirected_to new_session_url
    assert_equal "Please sign in to access the admin area.", flash[:alert]
  end
  
  test "unauthenticated user cannot access admin panel" do
    get rails_admin_path
    assert_redirected_to new_session_url
    assert_equal "Please sign in to access the admin area.", flash[:alert]
  end
  
  test "admin can view users list" do
    # Sign in as admin
    post session_path, params: {
      email_address: @admin_user.email_address,
      password: "password123"
    }
    follow_redirect!
    
    # Access users list
    get rails_admin.index_path(model_name: "user")
    assert_response :success
    assert_match @admin_user.email_address, response.body
    assert_match @regular_user.email_address, response.body
  end
  
  test "admin can edit user" do
    # Sign in as admin
    post session_path, params: {
      email_address: @admin_user.email_address,
      password: "password123"
    }
    follow_redirect!
    
    # Edit regular user
    get rails_admin.edit_path(model_name: "user", id: @regular_user.id)
    assert_response :success
    
    # Update user
    patch rails_admin.update_path(model_name: "user", id: @regular_user.id), params: {
      user: {
        full_name: "Updated Name",
        company: "Test Company"
      }
    }
    
    @regular_user.reload
    assert_equal "Updated Name", @regular_user.full_name
    assert_equal "Test Company", @regular_user.company
  end
  
  test "admin actions are logged in audit trail" do
    # Sign in as admin
    post session_path, params: {
      email_address: @admin_user.email_address,
      password: "password123"
    }
    follow_redirect!
    
    # Create a new user via admin panel
    assert_difference 'AdminAuditLog.count', 1 do
      post rails_admin.create_path(model_name: "user"), params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "marketer"
        }
      }
    end
    
    audit_log = AdminAuditLog.last
    assert_equal @admin_user, audit_log.user
    assert_equal "created_user", audit_log.action
    assert_equal "User", audit_log.auditable_type
    assert audit_log.ip_address.present?
    assert audit_log.user_agent.present?
  end
  
  test "admin can view audit logs" do
    # Create some audit logs
    AdminAuditLog.create!(
      user: @admin_user,
      action: "created_user",
      auditable_type: "User",
      auditable_id: @regular_user.id,
      ip_address: "127.0.0.1"
    )
    
    # Sign in as admin
    post session_path, params: {
      email_address: @admin_user.email_address,
      password: "password123"
    }
    follow_redirect!
    
    # View audit logs
    get rails_admin.index_path(model_name: "admin_audit_log")
    assert_response :success
    assert_match "created_user", response.body
    assert_match @admin_user.email_address, response.body
  end
end