require "test_helper"

class ActivityLoggerTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @session = Session.create!(user: @user)
    Current.session = @session
    Current.ip_address = "192.168.1.100"
    Current.user_agent = "Mozilla/5.0"
    Current.session_id = "test-session-123"
  end
  
  teardown do
    Current.reset
  end
  
  test "logs general messages with context" do
    assert_nothing_raised do
      ActivityLogger.log(:info, "Test message", { action: "test" })
    end
  end
  
  test "logs security events" do
    # Should log without error
    assert_nothing_raised do
      ActivityLogger.security('authentication_failure', "Failed login attempt", {
        email: "test@example.com",
        ip: "192.168.1.100"
      })
    end
  end
  
  test "logs performance metrics" do
    assert_nothing_raised do
      ActivityLogger.performance('slow_request', "Request took 2000ms", {
        controller: "users",
        action: "index",
        duration: 2000
      })
    end
  end
  
  test "logs audit events" do
    resource = @user
    
    assert_difference 'AdminAuditLog.count', 1 do
      ActivityLogger.audit('update', resource, { email_address: ["old@example.com", "new@example.com"] }, @user)
    end
    
    audit_log = AdminAuditLog.last
    assert_equal @user, audit_log.user
    assert_equal 'update', audit_log.action
    assert_equal resource, audit_log.auditable
  end
  
  test "sanitizes sensitive data from audit logs" do
    resource = @user
    sensitive_changes = {
      password: ["old", "new"],
      password_confirmation: ["old", "new"],
      email_address: ["old@example.com", "new@example.com"]
    }
    
    ActivityLogger.audit('update', resource, sensitive_changes, @user)
    
    audit_log = AdminAuditLog.last
    changes = JSON.parse(audit_log.change_details)
    
    assert_nil changes["password"]
    assert_nil changes["password_confirmation"]
    assert_equal ["old@example.com", "new@example.com"], changes["email_address"]
  end
  
  test "persists important logs to database" do
    assert_difference 'Activity.count', 1 do
      ActivityLogger.log(:error, "Critical error occurred", {
        controller: "test",
        action: "error",
        security_event: true
      })
    end
    
    activity = Activity.last
    assert_equal @user, activity.user
    assert activity.suspicious?
    assert_equal "Critical error occurred", activity.metadata["message"]
  end
  
  test "handles database persistence failures gracefully" do
    Activity.stubs(:create!).raises(ActiveRecord::RecordInvalid)
    
    # Should not raise error
    assert_nothing_raised do
      ActivityLogger.log(:error, "Test message", {})
    end
  end
  
  test "only logs valid security events" do
    # Invalid event type should not log
    assert_nothing_raised do
      ActivityLogger.security('invalid_event', "This should not log", {})
    end
    
    # Valid event type should log
    assert_nothing_raised do
      ActivityLogger.security('suspicious_activity', "Valid security event", {})
    end
  end
  
  test "only logs valid performance events" do
    # Invalid metric type should not log
    assert_nothing_raised do
      ActivityLogger.performance('invalid_metric', "This should not log", {})
    end
    
    # Valid metric type should log
    assert_nothing_raised do
      ActivityLogger.performance('slow_request', "Valid performance metric", {})
    end
  end
end