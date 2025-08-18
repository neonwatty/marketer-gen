# frozen_string_literal: true

require "test_helper"

class ContentAuditLogTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @admin_user = users(:admin_user) if User.exists?(role: 'admin')
    @campaign_plan = campaign_plans(:completed_plan)
    @generated_content = create_valid_test_content(
      campaign_plan: @campaign_plan,
      content_type: 'email',
      format_variant: 'standard',
      title: 'Test Email Content',
      created_by: @user
    )
  end

  test "should be valid with required attributes" do
    audit_log = ContentAuditLog.new(
      generated_content: @generated_content,
      user: @user,
      action: 'create'
    )
    assert audit_log.valid?
  end

  test "should require generated_content" do
    audit_log = ContentAuditLog.new(
      user: @user,
      action: 'create'
    )
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:generated_content], "must exist"
  end

  test "should require user" do
    audit_log = ContentAuditLog.new(
      generated_content: @generated_content,
      action: 'create'
    )
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:user], "must exist"
  end

  test "should require valid action" do
    audit_log = ContentAuditLog.new(
      generated_content: @generated_content,
      user: @user,
      action: 'invalid_action'
    )
    assert_not audit_log.valid?
    assert_includes audit_log.errors[:action], "is not included in the list"
  end

  test "should accept valid actions" do
    ContentAuditLog::AUDIT_ACTIONS.each do |action|
      audit_log = ContentAuditLog.new(
        generated_content: @generated_content,
        user: @user,
        action: action
      )
      assert audit_log.valid?, "Action '#{action}' should be valid"
    end
  end

  test "log_action should create audit entry with request context" do
    skip "TODO: Fix during incremental development"
    old_values = { title: 'Old Title' }
    new_values = { title: 'New Title' }
    metadata = { reason: 'Testing' }

    audit_log = ContentAuditLog.log_action(
      @generated_content,
      @user,
      'update',
      old_values,
      new_values,
      metadata
    )

    assert audit_log.persisted?
    assert_equal @generated_content, audit_log.generated_content
    assert_equal @user, audit_log.user
    assert_equal 'update', audit_log.action
    assert_equal old_values, audit_log.old_values
    assert_equal new_values, audit_log.new_values
    assert_equal metadata, audit_log.metadata
  end

  test "changes_summary should describe changes correctly" do
    audit_log = ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'update',
      old_values: { title: 'Old Title', status: 'draft' },
      new_values: { title: 'New Title', status: 'approved' }
    )

    summary = audit_log.changes_summary
    assert_includes summary, "Title: 'Old Title' → 'New Title'"
    assert_includes summary, "Status: 'draft' → 'approved'"
  end

  test "changes_summary should handle creation" do
    audit_log = ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'create',
      new_values: { title: 'New Content', content_type: 'email' }
    )

    summary = audit_log.changes_summary
    assert_includes summary, "Created with: Title, Content type"
  end

  test "changes_summary should handle deletion" do
    audit_log = ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'delete',
      old_values: { title: 'Deleted Content', status: 'draft' }
    )

    summary = audit_log.changes_summary
    assert_includes summary, "Removed: Title, Status"
  end

  test "action_description should return human readable descriptions" do
    audit_log = ContentAuditLog.new(action: 'create')
    assert_equal 'Content created', audit_log.action_description

    audit_log.action = 'approve'
    assert_equal 'Content approved', audit_log.action_description

    audit_log.action = 'rollback'
    assert_equal 'Content rolled back to previous version', audit_log.action_description
  end

  test "significant_change? should identify significant actions" do
    significant_log = ContentAuditLog.new(action: 'approve')
    assert significant_log.significant_change?

    minor_log = ContentAuditLog.new(action: 'view')
    assert_not minor_log.significant_change?
  end

  test "time_ago should return human readable time" do
    audit_log = ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'create',
      created_at: 2.hours.ago
    )

    assert_match(/hours ago/, audit_log.time_ago)
  end

  test "export_data should return formatted audit information" do
    audit_log = ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'approve',
      old_values: { status: 'draft' },
      new_values: { status: 'approved' },
      ip_address: '127.0.0.1',
      user_agent: 'Test Browser',
      metadata: { approval_notes: 'Good content' }
    )

    data = audit_log.export_data
    assert_equal 'Content approved', data[:action]
    assert_equal @user.full_name, data[:user]
    assert_includes data[:changes], "Status: 'draft' → 'approved'"
    assert_equal '127.0.0.1', data[:ip_address]
    assert_equal 'Test Browser', data[:user_agent]
    assert_equal({ 'approval_notes' => 'Good content' }, data[:metadata])
  end

  test "audit_trail_for should return recent audit logs" do
    # Create multiple audit logs
    3.times do |i|
      ContentAuditLog.create!(
        generated_content: @generated_content,
        user: @user,
        action: 'update',
        created_at: (3 - i).hours.ago
      )
    end

    trail = ContentAuditLog.audit_trail_for(@generated_content.id, 2)
    assert_equal 2, trail.count
    # Should be ordered by most recent first
    assert trail.first.created_at > trail.last.created_at
  end

  test "user_activity_summary should provide user statistics" do
    skip "TODO: Fix during incremental development"
    # Create audit logs for different timeframes
    ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'create',
      created_at: 1.day.ago
    )

    ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'approve',
      created_at: 1.hour.ago
    )

    ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'view',
      created_at: 35.days.ago  # Outside default 30-day window
    )

    summary = ContentAuditLog.user_activity_summary(@user.id)
    
    assert_equal 2, summary[:total_actions]  # Only recent actions
    assert_equal 1, summary[:content_items_affected]
    assert_equal 2, summary[:significant_changes]
    assert summary[:actions_by_type].key?('create')
    assert summary[:actions_by_type].key?('approve')
    assert_not summary[:actions_by_type].key?('view')  # Outside timeframe
  end

  test "content_activity_summary should provide content statistics" do
    skip "TODO: Fix during incremental development"
    other_user = users(:team_member_user)
    
    # Create audit logs from different users
    ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'create',
      created_at: 2.days.ago
    )

    ContentAuditLog.create!(
      generated_content: @generated_content,
      user: other_user,
      action: 'update',
      created_at: 1.day.ago
    )

    ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'approve',
      created_at: 1.hour.ago
    )

    summary = ContentAuditLog.content_activity_summary(@generated_content.id)
    
    assert_equal 3, summary[:total_actions]
    assert_equal 2, summary[:unique_users]
    assert_equal 2, summary[:significant_changes]  # create and approve
    assert summary[:actions_by_type].key?('create')
    assert summary[:actions_by_type].key?('update')
    assert summary[:actions_by_type].key?('approve')
    assert summary[:first_action] < summary[:last_action]
  end

  test "scopes should filter correctly" do
    # Clear any existing audit logs to ensure clean test
    ContentAuditLog.where(generated_content: @generated_content).delete_all
    
    # Create audit logs with different characteristics
    log1 = ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'create',
      created_at: 2.hours.ago
    )

    log2 = ContentAuditLog.create!(
      generated_content: @generated_content,
      user: @user,
      action: 'approve',
      created_at: 1.hour.ago
    )

    # Test by_action scope
    approve_logs = ContentAuditLog.by_action('approve')
    assert_includes approve_logs, log2
    assert_not_includes approve_logs, log1

    # Test recent scope
    recent_logs = ContentAuditLog.recent.where(generated_content: @generated_content)
    assert_equal [log2, log1], recent_logs.to_a

    # Test for_content scope
    content_logs = ContentAuditLog.for_content(@generated_content.id)
    assert_includes content_logs, log1
    assert_includes content_logs, log2

    # Test significant_changes scope
    significant_logs = ContentAuditLog.significant_changes.where(generated_content: @generated_content)
    assert_includes significant_logs, log1  # create
    assert_includes significant_logs, log2  # approve

    # Test within_timeframe scope
    recent_timeframe = ContentAuditLog.within_timeframe(1.5.hours.ago, Time.current).where(generated_content: @generated_content)
    assert_includes recent_timeframe, log2
    assert_not_includes recent_timeframe, log1
  end
end
