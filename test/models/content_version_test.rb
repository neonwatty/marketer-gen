# frozen_string_literal: true

require "test_helper"

class ContentVersionTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
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
    version = ContentVersion.new(
      generated_content: @generated_content,
      version_number: 2,
      action_type: 'created',
      changed_by: @user,
      timestamp: Time.current
    )
    assert version.valid?
  end

  test "should require generated_content" do
    version = ContentVersion.new(
      version_number: 1,
      action_type: 'created',
      changed_by: @user,
      timestamp: Time.current
    )
    assert_not version.valid?
    assert_includes version.errors[:generated_content], "must exist"
  end

  test "should require version_number" do
    version = ContentVersion.new(
      generated_content: @generated_content,
      action_type: 'created',
      changed_by: @user,
      timestamp: Time.current
    )
    assert_not version.valid?
    assert_includes version.errors[:version_number], "can't be blank"
  end

  test "should require valid action_type" do
    version = ContentVersion.new(
      generated_content: @generated_content,
      version_number: 1,
      action_type: 'invalid_action',
      changed_by: @user,
      timestamp: Time.current
    )
    assert_not version.valid?
    assert_includes version.errors[:action_type], "is not included in the list"
  end

  test "should have unique version_number per content" do
    # Clear existing versions to have a clean test
    @generated_content.version_logs.destroy_all
    
    ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 1,
      action_type: 'created',
      changed_by: @user,
      timestamp: Time.current
    )

    duplicate_version = ContentVersion.new(
      generated_content: @generated_content,
      version_number: 1,
      action_type: 'updated',
      changed_by: @user,
      timestamp: Time.current
    )
    
    assert_not duplicate_version.valid?
    assert_includes duplicate_version.errors[:version_number], "has already been taken"
  end

  test "should allow same version_number for different content" do
    other_content = create_valid_test_content(
      campaign_plan: @campaign_plan,
      content_type: 'blog_article',
      format_variant: 'standard',
      title: 'Other Content',
      created_by: @user
    )

    version1 = ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 2,
      action_type: 'updated',
      changed_by: @user,
      timestamp: Time.current
    )

    version2 = ContentVersion.new(
      generated_content: other_content,
      version_number: 2,
      action_type: 'updated',
      changed_by: @user,
      timestamp: Time.current
    )

    assert version2.valid?
  end

  test "next_version_number should increment correctly" do
    # Clear existing versions to have a clean test
    @generated_content.version_logs.destroy_all
    
    ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 1,
      action_type: 'created',
      changed_by: @user,
      timestamp: Time.current
    )

    ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 2,
      action_type: 'updated',
      changed_by: @user,
      timestamp: Time.current
    )

    next_version = ContentVersion.next_version_number(@generated_content.id)
    assert_equal 3, next_version
  end

  test "next_version_number should start at 1 for new content" do
    new_content = GeneratedContent.create!(
      campaign_plan: @campaign_plan,
      content_type: 'social_post',
      format_variant: 'short',
      title: 'New Content',
      body_content: 'New content without versions.',
      status: 'draft',
      version_number: 1,
      created_by: @user
    )

    # After creating content, an automatic ContentVersion is created via callback
    # So the next version number should be 2 (since version 1 already exists)
    next_version = ContentVersion.next_version_number(new_content.id)
    assert_equal 2, next_version
  end

  test "version_history_for should return versions in reverse chronological order" do
    # Clear existing versions to have a clean test
    @generated_content.version_logs.destroy_all
    
    version1 = ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 2,
      action_type: 'created',
      changed_by: @user,
      timestamp: 2.hours.ago
    )

    version2 = ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 3,
      action_type: 'updated',
      changed_by: @user,
      timestamp: 1.hour.ago
    )

    history = ContentVersion.version_history_for(@generated_content.id)
    assert_equal [version2, version1], history.to_a
  end

  test "create_version! should create version with correct attributes" do
    version = ContentVersion.create_version!(
      @generated_content,
      'updated',
      @user,
      'Test update',
      { test_metadata: 'value' }
    )

    assert version.persisted?
    assert_equal @generated_content, version.generated_content
    assert_equal 'updated', version.action_type
    assert_equal @user, version.changed_by
    assert_equal 'Test update', version.changes_summary
    assert_equal({ 'test_metadata' => 'value' }, version.metadata)
  end

  test "action_description should return human readable text" do
    version = ContentVersion.new(action_type: 'created')
    assert_equal 'Content created', version.action_description

    version.action_type = 'regenerated'
    assert_equal 'Content regenerated', version.action_description
  end

  test "significant_change? should identify significant actions" do
    significant_version = ContentVersion.new(action_type: 'approved')
    assert significant_version.significant_change?

    minor_version = ContentVersion.new(action_type: 'updated')
    assert_not minor_version.significant_change?
  end

  test "time_ago should return human readable time difference" do
    version = ContentVersion.new(timestamp: 2.hours.ago)
    assert_match(/hours ago/, version.time_ago)

    version.timestamp = 30.seconds.ago
    assert_match(/seconds ago/, version.time_ago)
  end

  test "export_data should return formatted version information" do
    version = ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 2,
      action_type: 'approved',
      changed_by: @user,
      changes_summary: 'Approved for publication',
      timestamp: Time.current,
      metadata: { approval_notes: 'Good content' }
    )

    data = version.export_data
    assert_equal 2, data[:version_number]
    assert_equal 'Content approved', data[:action]
    assert_equal @user.full_name, data[:changed_by]
    assert_equal 'Approved for publication', data[:summary]
    assert_equal({ 'approval_notes' => 'Good content' }, data[:metadata])
  end

  test "scopes should filter correctly" do
    # Clear existing versions to have a clean test
    @generated_content.version_logs.destroy_all
    
    version1 = ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 2,
      action_type: 'created',
      changed_by: @user,
      timestamp: 2.hours.ago
    )

    version2 = ContentVersion.create!(
      generated_content: @generated_content,
      version_number: 3,
      action_type: 'approved',
      changed_by: @user,
      timestamp: 1.hour.ago
    )

    # Test by_action scope
    approved_versions = ContentVersion.by_action('approved')
    assert_includes approved_versions, version2
    assert_not_includes approved_versions, version1

    # Test recent scope
    recent_versions = ContentVersion.recent.for_content(@generated_content.id)
    assert_equal [version2, version1], recent_versions.to_a

    # Test for_content scope
    content_versions = ContentVersion.for_content(@generated_content.id)
    assert_includes content_versions, version1
    assert_includes content_versions, version2
  end
end
