require "test_helper"
require "ostruct"

class AdminAuditLogTest < ActiveSupport::TestCase
  setup do
    AdminAuditLog.delete_all
    @user = User.create!(
      email_address: "test@example.com",
      password: "password",
      role: "admin"
    )
    
    @auditable = User.create!(
      email_address: "auditable@example.com",
      password: "password",
      role: "marketer"
    )
  end
  
  test "should create audit log with required attributes" do
    audit_log = AdminAuditLog.create!(
      user: @user,
      action: "created_user"
    )
    
    assert audit_log.persisted?
    assert_equal @user, audit_log.user
    assert_equal "created_user", audit_log.action
  end
  
  test "should require action" do
    audit_log = AdminAuditLog.new(user: @user)
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:action], "can't be blank"
  end
  
  test "should require user" do
    audit_log = AdminAuditLog.new(action: "test_action")
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:user], "must exist"
  end
  
  test "should accept polymorphic auditable" do
    audit_log = AdminAuditLog.create!(
      user: @user,
      action: "updated_user",
      auditable: @auditable
    )
    
    assert_equal @auditable, audit_log.auditable
    assert_equal "User", audit_log.auditable_type
    assert_equal @auditable.id, audit_log.auditable_id
  end
  
  test "log_action class method creates audit log" do
    request = OpenStruct.new(
      remote_ip: "192.168.1.1",
      user_agent: "Mozilla/5.0"
    )
    
    changes = { email_address: ["old@example.com", "new@example.com"] }
    
    audit_log = AdminAuditLog.log_action(
      user: @user,
      action: "updated_user",
      auditable: @auditable,
      changes: changes,
      request: request
    )
    
    assert audit_log.persisted?
    assert_equal @user, audit_log.user
    assert_equal "updated_user", audit_log.action
    assert_equal @auditable, audit_log.auditable
    assert_equal "192.168.1.1", audit_log.ip_address
    assert_equal "Mozilla/5.0", audit_log.user_agent
    assert_equal changes.stringify_keys, audit_log.parsed_changes
  end
  
  test "parsed_changes returns parsed JSON" do
    changes = { name: ["Old", "New"], status: ["active", "inactive"] }
    audit_log = AdminAuditLog.create!(
      user: @user,
      action: "test",
      change_details: changes.to_json
    )
    
    assert_equal changes.stringify_keys, audit_log.parsed_changes
  end
  
  test "parsed_changes returns empty hash for invalid JSON" do
    audit_log = AdminAuditLog.create!(
      user: @user,
      action: "test",
      change_details: "invalid json"
    )
    
    assert_equal({}, audit_log.parsed_changes)
  end
  
  test "parsed_changes returns empty hash when nil" do
    audit_log = AdminAuditLog.create!(
      user: @user,
      action: "test",
      change_details: nil
    )
    
    assert_equal({}, audit_log.parsed_changes)
  end
  
  test "recent scope orders by created_at desc" do
    old_log = AdminAuditLog.create!(
      user: @user,
      action: "old_action",
      created_at: 2.days.ago
    )
    
    new_log = AdminAuditLog.create!(
      user: @user,
      action: "new_action",
      created_at: 1.hour.ago
    )
    
    assert_equal [new_log, old_log], AdminAuditLog.recent.to_a
  end
  
  test "by_user scope filters by user" do
    other_user = User.create!(
      email_address: "other@example.com",
      password: "password",
      role: "admin"
    )
    
    user_log = AdminAuditLog.create!(user: @user, action: "test1")
    other_log = AdminAuditLog.create!(user: other_user, action: "test2")
    
    assert_includes AdminAuditLog.by_user(@user), user_log
    assert_not_includes AdminAuditLog.by_user(@user), other_log
  end
  
  test "by_action scope filters by action" do
    create_log = AdminAuditLog.create!(user: @user, action: "created_user")
    update_log = AdminAuditLog.create!(user: @user, action: "updated_user")
    
    assert_includes AdminAuditLog.by_action("created_user"), create_log
    assert_not_includes AdminAuditLog.by_action("created_user"), update_log
  end
end