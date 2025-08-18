# frozen_string_literal: true

require 'test_helper'

class SimpleVersionTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:completed_plan)
    @content = GeneratedContent.create!(
      campaign_plan: @campaign_plan,
      content_type: 'email',
      format_variant: 'standard',
      title: 'Test Content',
      body_content: 'This is test content for version testing. It needs to be longer to meet the validation requirements for standard format content which requires at least 100 characters.',
      status: 'draft',
      version_number: 1,
      created_by: @user
    )
  end

  test "should create content version" do
    version = ContentVersion.new(
      generated_content: @content,
      version_number: 2,
      action_type: 'created',
      changed_by: @user,
      timestamp: Time.current
    )
    
    assert version.save
    assert_equal @content, version.generated_content
    assert_equal 2, version.version_number
    assert_equal 'created', version.action_type
    assert_equal @user, version.changed_by
  end

  test "should create content audit log" do
    audit_log = ContentAuditLog.new(
      generated_content: @content,
      user: @user,
      action: 'create'
    )
    
    assert audit_log.save
    assert_equal @content, audit_log.generated_content
    assert_equal @user, audit_log.user
    assert_equal 'create', audit_log.action
  end

  test "should create new version of content" do
    new_version = @content.create_new_version!(@user, 'Test version')
    
    assert new_version.persisted?
    assert_equal @content.id, new_version.original_content_id
    assert_equal 2, new_version.version_number
    assert_equal @user, new_version.created_by
  end

  test "should compare content versions" do
    new_version = @content.create_new_version!(@user, 'Test version')
    new_version.update!(title: 'Updated Title')
    
    comparison = new_version.compare_with_version(@content)
    
    assert comparison[:title][:changed]
    assert_equal @content.title, comparison[:title][:old]
    assert_equal new_version.title, comparison[:title][:new]
  end
end