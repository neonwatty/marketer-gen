# frozen_string_literal: true

require 'test_helper'

class GeneratedContentVersionTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @other_user = users(:team_member_user)
    @campaign_plan = campaign_plans(:completed_plan)
    
    @original_content = create_valid_test_content(
      campaign_plan: @campaign_plan,
      content_type: 'email',
      format_variant: 'standard',
      title: 'Original Email Title',
      created_by: @user
    )
  end

  test "should create new version with proper attributes" do
    new_version = @original_content.create_new_version!(@other_user, 'Creating updated version')
    
    assert new_version.persisted?
    assert_equal @original_content.id, new_version.original_content_id
    assert_equal 2, new_version.version_number
    assert_equal @other_user, new_version.created_by
    assert_equal 'draft', new_version.status
    assert_nil new_version.approved_by_id
    
    # Check metadata
    assert_equal 'Creating updated version', new_version.metadata['change_summary']
    assert_equal 1, new_version.metadata['created_from_version']
    
    # Should create version log and audit log
    assert new_version.version_logs.exists?
    assert new_version.audit_logs.exists?
  end

  test "should maintain version chain correctly" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    version3 = version2.create_new_version!(@other_user, 'Version 3')
    
    # All versions should point to the original content
    assert_equal @original_content.id, version2.original_content_id
    assert_equal @original_content.id, version3.original_content_id
    
    # Version numbers should increment
    assert_equal 2, version2.version_number
    assert_equal 3, version3.version_number
    
    # Version history chain should include all versions
    history = @original_content.version_history_chain
    assert_equal 3, history.length
    assert_includes history, @original_content
    assert_includes history, version2
    assert_includes history, version3
  end

  test "should identify original vs version content correctly" do
    version = @original_content.create_new_version!(@user, 'New version')
    
    assert @original_content.original_version?
    assert_not version.original_version?
    
    assert version.version_of?(@original_content)
    assert_not @original_content.version_of?(version)
  end

  test "should identify latest version correctly" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    version3 = @original_content.create_new_version!(@user, 'Version 3')
    
    assert_not @original_content.latest_version?
    assert_not version2.latest_version?
    assert version3.latest_version?
    
    # Get latest version should return the most recent
    latest = @original_content.get_latest_version
    assert_equal version3, latest
  end

  test "should compare versions accurately" do
    version2 = @original_content.create_new_version!(@user, 'Updated version')
    version2.update!(
      title: 'Updated Email Title',
      body_content: 'This is completely different content with new information and different structure. It contains substantial text to meet validation requirements for standard format content and provides comprehensive testing coverage for version comparison functionality.',
      status: 'approved'
    )
    
    comparison = version2.compare_with_version(@original_content)
    
    assert comparison[:title][:changed]
    assert_equal @original_content.title, comparison[:title][:old]
    assert_equal version2.title, comparison[:title][:new]
    
    assert comparison[:body_content][:changed]
    assert comparison[:status][:changed]
    assert_not comparison[:content_type][:changed]
    
    # Word count change should reflect the difference
    word_count_diff = version2.word_count - @original_content.word_count
    assert_equal word_count_diff, comparison[:word_count_change]
  end

  test "should rollback to previous version successfully" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    version2.update!(
      title: 'Modified Title',
      body_content: 'Modified content that we want to revert. This contains substantial modifications and text to meet validation requirements for standard format content during rollback testing procedures.',
      status: 'approved'
    )
    
    rollback = version2.rollback_to_version!(@original_content, @other_user, 'Reverting problematic changes')
    
    assert rollback.persisted?
    assert_equal @original_content.title, rollback.title
    assert_equal @original_content.body_content, rollback.body_content
    assert_equal @original_content.content_type, rollback.content_type
    assert_equal @original_content.format_variant, rollback.format_variant
    assert_equal 'draft', rollback.status
    assert_equal @other_user, rollback.created_by
    assert rollback.version_number > version2.version_number
    
    # Check rollback metadata
    assert_equal version2.version_number, rollback.metadata['rolled_back_from_version']
    assert_equal @original_content.version_number, rollback.metadata['rolled_back_to_version']
    assert_equal 'Reverting problematic changes', rollback.metadata['rollback_reason']
    
    # Should create audit trail
    assert rollback.version_logs.where(action_type: 'rolled_back').exists?
    assert rollback.audit_logs.where(action: 'rollback').exists?
  end

  test "should not allow rollback to same or newer version" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    
    # Cannot rollback to same version
    result = version2.rollback_to_version!(version2, @user)
    assert_not result
    
    # Cannot rollback to newer version
    result = @original_content.rollback_to_version!(version2, @user)
    assert_not result
  end

  test "should get previous and next versions correctly" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    version3 = @original_content.create_new_version!(@user, 'Version 3')
    
    # Original content should have no previous, version2 as next
    assert_nil @original_content.get_previous_version
    assert_equal version2, @original_content.get_next_version
    
    # Version2 should have original as previous, version3 as next
    assert_equal @original_content, version2.get_previous_version
    assert_equal version3, version2.get_next_version
    
    # Version3 should have version2 as previous, no next
    assert_equal version2, version3.get_previous_version
    assert_nil version3.get_next_version
  end

  test "should get changes from previous version" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    version2.update!(
      title: 'Changed Title',
      body_content: 'Completely rewritten content with different focus and approach. This comprehensive rewrite includes substantial text modifications to meet validation requirements for standard format content testing scenarios.'
    )
    
    changes = version2.changes_from_previous_version
    
    assert changes[:title][:changed]
    assert changes[:body_content][:changed]
    assert_not changes[:content_type][:changed]
    assert_not changes[:format_variant][:changed]
  end

  test "should get detailed version history with audit trail" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    version2.approve!(@other_user)
    
    detailed_history = @original_content.detailed_version_history
    
    assert_equal 2, detailed_history.length
    
    detailed_history.each do |entry|
      assert entry.key?(:version)
      assert entry.key?(:version_logs)
      assert entry.key?(:audit_logs)
      
      version = entry[:version]
      assert version.is_a?(GeneratedContent)
      
      # Should include related audit and version logs
      assert entry[:version_logs].respond_to?(:each)
      assert entry[:audit_logs].respond_to?(:each)
    end
  end

  test "should handle status changes with audit logging" do
    # Test submit for review
    result = @original_content.submit_for_review!(@user)
    assert result
    assert_equal 'in_review', @original_content.status
    assert @original_content.version_logs.where(action_type: 'updated').exists?
    assert @original_content.audit_logs.where(action: 'update').exists?
    
    # Test approval
    result = @original_content.approve!(@other_user)
    assert result
    assert_equal 'approved', @original_content.status
    assert_equal @other_user, @original_content.approver
    assert @original_content.version_logs.where(action_type: 'approved').exists?
    assert @original_content.audit_logs.where(action: 'approve').exists?
    
    # Test publishing
    result = @original_content.publish!(@user)
    assert result
    assert_equal 'published', @original_content.status
    assert @original_content.version_logs.where(action_type: 'published').exists?
    assert @original_content.audit_logs.where(action: 'publish').exists?
    
    # Test archiving
    result = @original_content.archive!(@user)
    assert result
    assert_equal 'archived', @original_content.status
    assert @original_content.version_logs.where(action_type: 'archived').exists?
    assert @original_content.audit_logs.where(action: 'archive').exists?
  end

  test "should handle rejection with reason" do
    @original_content.update!(status: 'in_review')
    
    result = @original_content.reject!(@other_user, 'Content needs significant revision')
    
    assert result
    assert_equal 'rejected', @original_content.status
    assert_equal 'Content needs significant revision', @original_content.metadata['rejection_reason']
    assert @original_content.version_logs.where(action_type: 'updated').exists?
    
    audit_log = @original_content.audit_logs.where(action: 'update').last
    assert_equal 'Content needs significant revision', audit_log.metadata['rejection_reason']
  end

  test "should not allow invalid status transitions" do
    # Cannot approve draft content
    result = @original_content.approve!(@user)
    assert_not result
    assert_equal 'draft', @original_content.status
    
    # Cannot publish non-approved content
    result = @original_content.publish!(@user)
    assert_not result
    assert_equal 'draft', @original_content.status
    
    # Cannot reject non-review content
    result = @original_content.reject!(@user, 'Test reason')
    assert_not result
    assert_equal 'draft', @original_content.status
  end

  test "should create audit trail on content creation and updates" do
    # Content creation should create audit trail
    new_content = create_valid_test_content(
      campaign_plan: @campaign_plan,
      content_type: 'blog_article',
      format_variant: 'standard',
      title: 'New Blog Article',
      created_by: @user
    )
    
    # Should have created version log and audit log
    assert new_content.version_logs.where(action_type: 'created').exists?
    assert new_content.audit_logs.where(action: 'create').exists?
    
    # Content update should create audit trail
    old_title = new_content.title
    new_content.update!(title: 'Updated Blog Article Title')
    
    # Should have created audit logs for the update
    version_log = new_content.version_logs.where(action_type: 'updated').last
    audit_log = new_content.audit_logs.where(action: 'update').last
    
    assert version_log.present?
    assert audit_log.present?
    assert_equal old_title, audit_log.old_values['title']
    assert_equal 'Updated Blog Article Title', audit_log.new_values['title']
  end

  test "should handle version associations correctly" do
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    version3 = @original_content.create_new_version!(@user, 'Version 3')
    
    # Original content should have version associations
    assert_equal 2, @original_content.content_versions.count
    assert_includes @original_content.content_versions, version2
    assert_includes @original_content.content_versions, version3
    
    # Version content should have audit and version log associations
    assert version2.version_logs.exists?
    assert version2.audit_logs.exists?
    assert version3.version_logs.exists?
    assert version3.audit_logs.exists?
    
    # Versions should not have their own content_versions
    assert_equal 0, version2.content_versions.count
    assert_equal 0, version3.content_versions.count
  end

  test "should calculate next version number correctly" do
    # For original content
    assert_equal 2, @original_content.next_version_number
    
    version2 = @original_content.create_new_version!(@user, 'Version 2')
    assert_equal 3, @original_content.next_version_number
    
    # For version content
    assert_equal 3, version2.next_version_number
    
    version3 = @original_content.create_new_version!(@user, 'Version 3')
    assert_equal 4, version2.next_version_number
    assert_equal 4, version3.next_version_number
  end
end