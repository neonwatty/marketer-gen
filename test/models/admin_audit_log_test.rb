require "test_helper"
require "ostruct"

class AdminAuditLogTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @user = users(:regular)
  end

  test "should create audit log with valid attributes" do
    assert_difference "AdminAuditLog.count", 1 do
      AdminAuditLog.log_action(
        user: @admin,
        action: "updated",
        auditable: @user,
        changes: { role: ["marketer", "admin"] }
      )
    end
    
    log = AdminAuditLog.last
    assert_equal @admin, log.user
    assert_equal "updated", log.action
    assert_equal @user, log.auditable
    assert_equal({ "role" => ["marketer", "admin"] }, log.parsed_changes)
  end

  test "should require user" do
    log = AdminAuditLog.new(action: "test")
    assert_not log.valid?
    assert_includes log.errors[:user], "must exist"
  end

  test "should require action" do
    log = AdminAuditLog.new(user: @admin)
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "should work without auditable" do
    assert_difference "AdminAuditLog.count", 1 do
      AdminAuditLog.log_action(
        user: @admin,
        action: "exported_data"
      )
    end
  end

  test "should capture request information" do
    request = OpenStruct.new(
      remote_ip: "192.168.1.1",
      user_agent: "Mozilla/5.0"
    )
    
    AdminAuditLog.log_action(
      user: @admin,
      action: "deleted",
      auditable: @user,
      request: request
    )
    
    log = AdminAuditLog.last
    assert_equal "192.168.1.1", log.ip_address
    assert_equal "Mozilla/5.0", log.user_agent
  end

  test "parsed_changes handles invalid JSON" do
    log = AdminAuditLog.create!(
      user: @admin,
      action: "test",
      change_details: "invalid json"
    )
    
    assert_equal({}, log.parsed_changes)
  end

  test "recent scope returns logs in descending order" do
    old_log = AdminAuditLog.create!(
      user: @admin,
      action: "old_action",
      created_at: 2.days.ago
    )
    
    new_log = AdminAuditLog.create!(
      user: @admin,
      action: "new_action"
    )
    
    logs = AdminAuditLog.recent
    assert_equal new_log, logs.first
    assert_equal old_log, logs.last
  end

  test "by_user scope filters by user" do
    other_admin = User.create!(
      email_address: "other@example.com",
      password: "password123",
      role: "admin"
    )
    
    log1 = AdminAuditLog.create!(user: @admin, action: "test1")
    log2 = AdminAuditLog.create!(user: other_admin, action: "test2")
    
    logs = AdminAuditLog.by_user(@admin)
    assert_includes logs, log1
    assert_not_includes logs, log2
  end

  test "by_action scope filters by action" do
    log1 = AdminAuditLog.create!(user: @admin, action: "suspended_user")
    log2 = AdminAuditLog.create!(user: @admin, action: "deleted_user")
    
    logs = AdminAuditLog.by_action("suspended_user")
    assert_includes logs, log1
    assert_not_includes logs, log2
  end
end