require "test_helper"

class PlanAuditLogTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @team_user = users(:team_member_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @plan_version = PlanVersion.create!(
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    @audit_log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "created",
      details: { plan_name: @campaign_plan.name }
    )
  end

  # Basic validations
  test "should be valid with valid attributes" do
    log = PlanAuditLog.new(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "updated"
    )
    assert log.valid?
  end

  test "should require campaign_plan" do
    @audit_log.campaign_plan = nil
    assert_not @audit_log.valid?
    assert_includes @audit_log.errors[:campaign_plan], "must exist"
  end

  test "should require user" do
    @audit_log.user = nil
    assert_not @audit_log.valid?
    assert_includes @audit_log.errors[:user], "must exist"
  end

  test "should require action" do
    @audit_log.action = nil
    assert_not @audit_log.valid?
    assert_includes @audit_log.errors[:action], "can't be blank"
  end

  test "should validate action inclusion" do
    @audit_log.action = "invalid_action"
    assert_not @audit_log.valid?
    assert_includes @audit_log.errors[:action], "is not included in the list"
  end

  test "should allow all valid actions" do
    valid_actions = %w[
      created updated submitted_for_approval approved rejected feedback_added 
      feedback_addressed feedback_resolved feedback_dismissed version_created 
      version_submitted_for_review version_approved version_rejected 
      stakeholder_invited stakeholder_removed plan_exported plan_shared
    ]
    
    valid_actions.each do |action|
      log = PlanAuditLog.new(
        campaign_plan: @campaign_plan,
        user: @user,
        action: action
      )
      assert log.valid?, "Action '#{action}' should be valid"
    end
  end

  # Associations
  test "should belong to campaign_plan" do
    assert_equal @campaign_plan, @audit_log.campaign_plan
  end

  test "should belong to user" do
    assert_equal @user, @audit_log.user
  end

  test "should optionally belong to plan_version" do
    assert_nil @audit_log.plan_version
    
    @audit_log.plan_version = @plan_version
    assert_equal @plan_version, @audit_log.plan_version
  end

  # Scopes
  test "recent scope should order by created_at desc" do
    sleep(0.01)
    log2 = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "updated"
    )
    
    recent_logs = PlanAuditLog.recent
    assert_equal log2, recent_logs.first
    assert_equal @audit_log, recent_logs.last
  end

  test "by_action scope should filter correctly" do
    update_log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "updated"
    )
    
    created_logs = PlanAuditLog.by_action("created")
    updated_logs = PlanAuditLog.by_action("updated")
    
    assert_includes created_logs, @audit_log
    assert_not_includes created_logs, update_log
    assert_includes updated_logs, update_log
    assert_not_includes updated_logs, @audit_log
  end

  test "by_user scope should filter correctly" do
    team_log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @team_user,
      action: "updated"
    )
    
    marketer_logs = PlanAuditLog.by_user(@user)
    team_logs = PlanAuditLog.by_user(@team_user)
    
    assert_includes marketer_logs, @audit_log
    assert_not_includes marketer_logs, team_log
    assert_includes team_logs, team_log
    assert_not_includes team_logs, @audit_log
  end

  test "for_plan_version scope should filter correctly" do
    version_log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      plan_version: @plan_version,
      user: @user,
      action: "version_created"
    )
    
    version_logs = PlanAuditLog.for_plan_version(@plan_version)
    assert_includes version_logs, version_log
    assert_not_includes version_logs, @audit_log
  end

  test "approval_related scope should filter correctly" do
    approval_log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "approved"
    )
    
    approval_logs = PlanAuditLog.approval_related
    assert_includes approval_logs, approval_log
    assert_not_includes approval_logs, @audit_log
  end

  test "feedback_related scope should filter correctly" do
    feedback_log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "feedback_added"
    )
    
    feedback_logs = PlanAuditLog.feedback_related
    assert_includes feedback_logs, feedback_log
    assert_not_includes feedback_logs, @audit_log
  end

  test "version_related scope should filter correctly" do
    version_log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "version_created"
    )
    
    version_logs = PlanAuditLog.version_related
    assert_includes version_logs, version_log
    assert_not_includes version_logs, @audit_log
  end

  # Class factory methods
  test "create_for_plan_update! should create proper audit log" do
    changes = {
      "name" => ["Old Name", "New Name"],
      "description" => [nil, "New description"]
    }
    
    log = PlanAuditLog.create_for_plan_update!(@campaign_plan, @user, changes)
    
    assert_equal "updated", log.action
    assert_equal @campaign_plan, log.campaign_plan
    assert_equal @user, log.user
    assert_equal ["name", "description"], log.details["changed_fields"]
    assert_equal changes, log.details["changes"]
    assert_not_nil log.details["updated_at"]
  end

  test "create_for_plan_creation! should create proper audit log" do
    log = PlanAuditLog.create_for_plan_creation!(@campaign_plan, @user)
    
    assert_equal "created", log.action
    assert_equal @campaign_plan, log.campaign_plan
    assert_equal @user, log.user
    assert_equal @campaign_plan.name, log.details["plan_name"]
    assert_equal @campaign_plan.campaign_type, log.details["campaign_type"]
    assert_equal @campaign_plan.objective, log.details["objective"]
    assert_not_nil log.details["created_at"]
  end

  test "create_for_stakeholder_action! should create proper audit log for invitation" do
    stakeholder = users(:admin_user)
    
    log = PlanAuditLog.create_for_stakeholder_action!(
      @campaign_plan, @user, stakeholder, "invited"
    )
    
    assert_equal "stakeholder_invited", log.action
    assert_equal @campaign_plan, log.campaign_plan
    assert_equal @user, log.user
    assert_equal stakeholder.id, log.details["stakeholder_id"]
    assert_equal stakeholder.full_name, log.details["stakeholder_name"]
    assert_equal stakeholder.email_address, log.details["stakeholder_email"]
    assert_equal "invited", log.details["action_performed"]
    assert_not_nil log.details["performed_at"]
  end

  test "create_for_stakeholder_action! should create proper audit log for removal" do
    stakeholder = users(:admin_user)
    
    log = PlanAuditLog.create_for_stakeholder_action!(
      @campaign_plan, @user, stakeholder, "removed"
    )
    
    assert_equal "stakeholder_removed", log.action
    assert_equal stakeholder.id, log.details["stakeholder_id"]
    assert_equal "removed", log.details["action_performed"]
  end

  test "create_for_export! should create proper audit log" do
    @campaign_plan.update!(current_version_id: @plan_version.id)
    
    log = PlanAuditLog.create_for_export!(@campaign_plan, @user, "pdf")
    
    assert_equal "plan_exported", log.action
    assert_equal @campaign_plan, log.campaign_plan
    assert_equal @user, log.user
    assert_equal "pdf", log.details["export_format"]
    assert_equal @plan_version.id, log.details["plan_version"]
    assert_not_nil log.details["exported_at"]
  end

  # Instance methods
  test "action_description should return formatted descriptions" do
    test_cases = [
      { action: "created", expected: "Campaign plan created" },
      { action: "updated", details: { "changed_fields" => ["name", "description"] }, 
        expected: "Plan updated: name, description" },
      { action: "submitted_for_approval", expected: "Plan submitted for approval" },
      { action: "approved", expected: "Plan approved" },
      { action: "rejected", expected: "Plan rejected" },
      { action: "feedback_added", details: { "comment_type" => "suggestion", "priority" => "high" },
        expected: "Feedback added: suggestion (high priority)" },
      { action: "feedback_addressed", expected: "Feedback addressed by team" },
      { action: "feedback_resolved", expected: "Feedback marked as resolved" },
      { action: "feedback_dismissed", expected: "Feedback dismissed" },
      { action: "version_created", details: { "version_number" => 2 },
        expected: "Version 2 created" },
      { action: "stakeholder_invited", details: { "stakeholder_name" => "John Doe" },
        expected: "Stakeholder invited: John Doe" },
      { action: "plan_exported", details: { "export_format" => "pdf" },
        expected: "Plan exported as pdf" },
      { action: "plan_shared", details: { "recipient_count" => 3 },
        expected: "Plan shared with 3 recipients" }
    ]
    
    test_cases.each do |test_case|
      log = PlanAuditLog.new(
        campaign_plan: @campaign_plan,
        user: @user,
        action: test_case[:action],
        details: test_case[:details] || {}
      )
      
      assert_equal test_case[:expected], log.action_description,
        "Failed for action: #{test_case[:action]}"
    end
  end

  test "user_name should return user name or fallback" do
    assert_equal @user.full_name, @audit_log.user_name
    
    # Test with deleted user scenario
    @audit_log.user = nil
    assert_equal "Unknown User", @audit_log.user_name
  end

  test "time_ago should use time_ago_in_words" do
    past_audit_log = nil
    travel_to 2.hours.ago do
      past_audit_log = PlanAuditLog.create!(
        campaign_plan: @campaign_plan,
        user: @user,
        action: "created",
        details: { plan_name: @campaign_plan.name }
      )
    end
    
    assert_includes past_audit_log.time_ago, "hour"
  end

  test "has_plan_version? should work correctly" do
    assert_not @audit_log.has_plan_version?
    
    @audit_log.plan_version = @plan_version
    assert @audit_log.has_plan_version?
  end

  test "version_number should return plan_version version_number" do
    assert_nil @audit_log.version_number
    
    @audit_log.plan_version = @plan_version
    assert_equal @plan_version.version_number, @audit_log.version_number
  end

  test "is_significant? should identify important actions" do
    significant_actions = %w[created approved rejected version_approved version_rejected feedback_added]
    insignificant_actions = %w[updated feedback_addressed plan_exported stakeholder_invited]
    
    significant_actions.each do |action|
      @audit_log.action = action
      assert @audit_log.is_significant?, "Action '#{action}' should be significant"
    end
    
    insignificant_actions.each do |action|
      @audit_log.action = action
      assert_not @audit_log.is_significant?, "Action '#{action}' should not be significant"
    end
  end

  test "involves_external_user? should identify external actions" do
    external_actions = %w[stakeholder_invited stakeholder_removed plan_shared]
    internal_actions = %w[created updated approved feedback_added]
    
    external_actions.each do |action|
      @audit_log.action = action
      assert @audit_log.involves_external_user?, "Action '#{action}' should involve external user"
    end
    
    internal_actions.each do |action|
      @audit_log.action = action
      assert_not @audit_log.involves_external_user?, "Action '#{action}' should not involve external user"
    end
  end

  # Class utility methods
  test "activity_summary should return comprehensive statistics" do
    # Create various audit logs for testing
    travel_to 20.days.ago do
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "created")
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "updated")
    end
    
    travel_to 10.days.ago do
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @team_user, action: "version_approved")
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @team_user, action: "feedback_added")
    end
    
    travel_to 5.days.ago do
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "plan_exported")
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "version_rejected")
    end
    
    summary = PlanAuditLog.activity_summary(30)
    
    assert_equal 7, summary[:total_activity] # 6 created above + 1 from setup
    assert_equal 2, summary[:plans_created] # 1 from test + 1 from setup
    assert_equal 1, summary[:plans_updated]
    assert_equal 1, summary[:approvals]
    assert_equal 1, summary[:rejections]
    assert_equal 1, summary[:feedback_items]
    assert_equal 1, summary[:exports]
    
    # Most active users should be sorted by activity count
    assert summary[:most_active_users].is_a?(Array)
    assert summary[:most_active_users].length > 0
    
    # Daily activity should be grouped
    assert summary[:daily_activity].is_a?(Hash)
  end

  test "activity_summary with different time ranges" do
    travel_to 40.days.ago do
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "created")
    end
    
    travel_to 10.days.ago do
      PlanAuditLog.create!(campaign_plan: @campaign_plan, user: @user, action: "updated")
    end
    
    # 30-day summary should exclude 40-day-old record
    summary_30 = PlanAuditLog.activity_summary(30)
    # 60-day summary should include both
    summary_60 = PlanAuditLog.activity_summary(60)
    
    assert summary_60[:total_activity] > summary_30[:total_activity]
  end

  test "audit_trail_for_plan should return relevant logs with includes" do
    # Create logs for different plans
    other_plan = campaign_plans(:completed_plan)
    PlanAuditLog.create!(campaign_plan: other_plan, user: @user, action: "created")
    
    # Create multiple logs for our plan
    log2 = PlanAuditLog.create!(
      campaign_plan: @campaign_plan, 
      plan_version: @plan_version,
      user: @team_user, 
      action: "version_created"
    )
    
    trail = PlanAuditLog.audit_trail_for_plan(@campaign_plan, 10)
    
    # Should include logs for our plan only
    assert_includes trail, @audit_log
    assert_includes trail, log2
    
    # Should not include logs for other plans
    assert_not_includes trail.map(&:campaign_plan), other_plan
    
    # Should be ordered by recent (created_at desc)
    assert_equal log2, trail.first
    assert_equal @audit_log, trail.last
    
    # Test limit functionality
    limited_trail = PlanAuditLog.audit_trail_for_plan(@campaign_plan, 1)
    assert_equal 1, limited_trail.count
    assert_equal log2, limited_trail.first
  end

  # Request metadata handling
  test "should capture request metadata if Current.request is available" do
    # Mock a request object
    mock_request = Object.new
    def mock_request.remote_ip; "192.168.1.1"; end
    def mock_request.user_agent; "Test Agent"; end
    def mock_request.controller_class; Object.new; end
    def mock_request.action_name; "create"; end
    def mock_request.method; "POST"; end
    def mock_request.path; "/campaign_plans"; end
    def mock_request.referer; "http://example.com"; end
    
    # Mock Current class
    current_class = Class.new do
      class << self
        attr_accessor :request
      end
    end
    
    # Skip this test since Current class is already defined in the app
    # and we don't want to interfere with it in tests
    skip "Current class handling tested in integration tests"
  end

  test "request_metadata should handle nil request gracefully" do
    metadata = PlanAuditLog.request_metadata(nil)
    assert_equal({}, metadata)
  end

  test "request_metadata should extract request information" do
    mock_request = Object.new
    def mock_request.controller_class
      controller = Object.new
      def controller.name; "CampaignPlansController"; end
      controller
    end
    def mock_request.action_name; "show"; end
    def mock_request.method; "GET"; end
    def mock_request.path; "/campaign_plans/1"; end
    def mock_request.referer; "http://example.com/dashboard"; end
    
    metadata = PlanAuditLog.request_metadata(mock_request)
    
    assert_equal "CampaignPlansController", metadata[:controller]
    assert_equal "show", metadata[:action]
    assert_equal "GET", metadata[:method]
    assert_equal "/campaign_plans/1", metadata[:path]
    assert_equal "http://example.com/dashboard", metadata[:referer]
    assert_not_nil metadata[:timestamp]
  end

  # JSON serialization
  test "should handle JSON details correctly" do
    complex_details = {
      "changed_fields" => ["name", "description"],
      "metadata" => { "version" => "2.0" },
      "counts" => { "comments" => 5, "approvals" => 2 }
    }
    
    log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "updated",
      details: complex_details
    )
    
    log.reload
    assert_equal complex_details, log.details
    assert_equal ["name", "description"], log.details["changed_fields"]
    assert_equal "2.0", log.details["metadata"]["version"]
  end

  test "should handle JSON metadata correctly" do
    complex_metadata = {
      "request_info" => { "ip" => "192.168.1.1", "agent" => "Browser" },
      "performance" => { "duration" => 150 }
    }
    
    log = PlanAuditLog.create!(
      campaign_plan: @campaign_plan,
      user: @user,
      action: "created",
      metadata: complex_metadata
    )
    
    log.reload
    assert_equal complex_metadata, log.metadata
    assert_equal 150, log.metadata["performance"]["duration"]
  end
end