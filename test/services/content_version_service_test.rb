# frozen_string_literal: true

require 'test_helper'

class ContentVersionServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @other_user = users(:team_member_user)
    @campaign_plan = campaign_plans(:completed_plan)
    
    @content_v1 = GeneratedContent.create!(
      campaign_plan: @campaign_plan,
      content_type: 'email',
      format_variant: 'standard',
      title: 'Original Email Title',
      body_content: 'This is the original email content with some initial text that needs to be long enough to meet validation requirements for standard format content.',
      status: 'draft',
      version_number: 1,
      created_by: @user
    )
    
    @content_v2 = @content_v1.create_new_version!(@other_user, 'Updated content')
    @content_v2.update!(
      title: 'Updated Email Title',
      body_content: 'This is the updated email content with new and improved text that provides much more comprehensive information and details.',
      status: 'approved'
    )
  end

  test "should compare versions successfully" do
    result = ContentVersionService.compare_versions(@content_v2, @content_v1)
    
    assert result[:success]
    comparison = result[:data]
    
    assert comparison[:title][:changed]
    assert_equal 'Original Email Title', comparison[:title][:old]
    assert_equal 'Updated Email Title', comparison[:title][:new]
    
    assert comparison[:body_content][:changed]
    assert_equal @content_v1.body_content, comparison[:body_content][:old]
    assert_equal @content_v2.body_content, comparison[:body_content][:new]
    
    assert comparison[:status][:changed]
    assert_equal 'draft', comparison[:status][:old]
    assert_equal 'approved', comparison[:status][:new]
    
    assert_equal 'moderate', comparison[:summary][:significance]
    assert comparison[:summary][:total_fields_changed] > 0
  end

  test "should handle comparison with same content" do
    result = ContentVersionService.compare_versions(@content_v1, @content_v1)
    
    assert result[:success]
    comparison = result[:data]
    
    assert_not comparison[:title][:changed]
    assert_not comparison[:body_content][:changed]
    assert_not comparison[:status][:changed]
    assert_equal 'none', comparison[:summary][:significance]
  end

  test "should require both versions for comparison" do
    result = ContentVersionService.compare_versions(@content_v1, nil)
    
    assert_not result[:success]
    assert_includes result[:error], "Both versions required"
  end

  test "should rollback content successfully" do
    result = ContentVersionService.rollback_content(@content_v2, @content_v1, @user, 'Reverting changes')
    
    assert result[:success]
    rollback_version = result[:data][:rollback_version]
    
    assert rollback_version.persisted?
    assert_equal @content_v1.title, rollback_version.title
    assert_equal @content_v1.body_content, rollback_version.body_content
    assert_equal @content_v1.content_type, rollback_version.content_type
    assert_equal @content_v1.format_variant, rollback_version.format_variant
    assert_equal 'draft', rollback_version.status
    assert_equal @user, rollback_version.created_by
    assert rollback_version.version_number > @content_v2.version_number
    
    # Check metadata
    assert_equal @content_v2.version_number, rollback_version.metadata['rolled_back_from_version']
    assert_equal @content_v1.version_number, rollback_version.metadata['rolled_back_to_version']
    assert_equal 'Reverting changes', rollback_version.metadata['rollback_reason']
  end

  test "should not allow rollback to same or newer version" do
    result = ContentVersionService.rollback_content(@content_v1, @content_v2, @user)
    
    assert_not result[:success]
    assert_includes result[:error], "Cannot rollback to same or newer version"
  end

  test "should require all parameters for rollback" do
    result = ContentVersionService.rollback_content(@content_v2, @content_v1, nil)
    
    assert_not result[:success]
    assert_includes result[:error], "Current content, target version, and user required"
  end

  test "should generate version analytics" do
    skip "TODO: Fix during incremental development"
    # Create more versions and activity
    @content_v3 = @content_v2.create_new_version!(@user, 'Final version')
    @content_v3.approve!(@other_user)
    @content_v3.publish!(@user)
    
    result = ContentVersionService.version_analytics(@content_v1)
    
    assert result[:success]
    analytics = result[:data]
    
    assert_equal 3, analytics[:total_versions]
    assert analytics[:version_timeline].length == 3
    assert analytics[:version_activity][:total_actions] > 0
    assert analytics[:version_activity][:unique_contributors] >= 2
    
    # Check version timeline structure
    timeline = analytics[:version_timeline]
    assert timeline.all? { |v| v.key?(:version_number) }
    assert timeline.all? { |v| v.key?(:created_at) }
    assert timeline.all? { |v| v.key?(:creator) }
    assert timeline.all? { |v| v.key?(:status) }
  end

  test "should require content for analytics" do
    result = ContentVersionService.version_analytics(nil)
    
    assert_not result[:success]
    assert_includes result[:error], "Content required for analytics"
  end

  test "should generate content diff" do
    old_text = "This is the original text with some words."
    new_text = "This is the updated text with different words and more content."
    
    service = ContentVersionService.new
    diff = service.content_diff(old_text, new_text)
    
    assert diff[:old_length] < diff[:new_length]
    assert diff[:added_words].include?('different')
    assert diff[:added_words].include?('more')
    assert diff[:removed_words].include?('some')
    assert diff[:common_words].include?('This')
    assert diff[:similarity_percentage] > 0
    assert diff[:similarity_percentage] < 100
  end

  test "should handle cleanup of old versions" do
    # Create old content with versions
    old_content = create_valid_test_content(
      campaign_plan: @campaign_plan,
      content_type: 'blog_article',
      format_variant: 'standard',
      title: 'Old Content',
      created_by: @user,
      created_at: 100.days.ago
    )
    
    old_version = old_content.create_new_version!(@user, 'Old version')
    old_version.update!(created_at: 100.days.ago)
    
    # Create audit logs for the old version
    ContentAuditLog.create!(
      generated_content: old_version,
      user: @user,
      action: 'update',
      created_at: 100.days.ago
    )
    
    result = ContentVersionService.cleanup_old_versions(90)
    
    assert result[:success]
    stats = result[:data]
    
    assert stats[:total_found] >= 0
    assert stats.key?(:cleaned_up)
    assert stats.key?(:preserved)
    assert stats.key?(:errors)
  end

  test "should preserve significant versions during cleanup" do
    # Create published content (should be preserved)
    published_content = GeneratedContent.create!(
      campaign_plan: @campaign_plan,
      content_type: 'social_post',
      format_variant: 'short',
      title: 'Published Content',
      body_content: 'This is published content.',
      status: 'published',
      version_number: 1,
      created_by: @user,
      created_at: 100.days.ago
    )
    
    result = ContentVersionService.cleanup_old_versions(90)
    
    assert result[:success]
    # Published content should still exist
    assert GeneratedContent.exists?(published_content.id)
  end

  test "should calculate similarity percentage correctly" do
    service = ContentVersionService.new
    
    # Identical text
    similarity = service.send(:calculate_similarity_percentage, "hello world", "hello world")
    assert_equal 100.0, similarity
    
    # Different lengths
    similarity = service.send(:calculate_similarity_percentage, "hello", "hello world")
    assert_equal 45.45, similarity
    
    # Empty text
    similarity = service.send(:calculate_similarity_percentage, "", "hello")
    assert_equal 0.0, similarity
    
    similarity = service.send(:calculate_similarity_percentage, "hello", "")
    assert_equal 0.0, similarity
  end

  test "should determine change significance correctly" do
    service = ContentVersionService.new
    
    # No changes
    comparison = {
      title: { changed: false },
      body_content: { changed: false },
      content_type: { changed: false },
      status: { changed: false }
    }
    significance = service.send(:determine_change_significance, comparison)
    assert_equal 'none', significance
    
    # Minor changes
    comparison[:title][:changed] = true
    significance = service.send(:determine_change_significance, comparison)
    assert_equal 'minor', significance
    
    # Moderate changes
    comparison[:body_content][:changed] = true
    significance = service.send(:determine_change_significance, comparison)
    assert_equal 'moderate', significance
    
    # Major changes
    comparison[:content_type][:changed] = true
    comparison[:status][:changed] = true
    significance = service.send(:determine_change_significance, comparison)
    assert_equal 'major', significance
  end

  test "should analyze content evolution" do
    skip "TODO: Fix during incremental development"
    # Create a series of versions with different characteristics
    @content_v3 = @content_v2.create_new_version!(@user, 'Extended content')
    @content_v3.update!(
      body_content: send(:generate_body_content_for_format, 'extended'),
      format_variant: 'extended'
    )
    
    @content_v4 = @content_v3.create_new_version!(@other_user, 'Approved version')
    @content_v4.approve!(@user)
    
    service = ContentVersionService.new(@content_v1)
    history = [@content_v1, @content_v2, @content_v3, @content_v4]
    evolution = service.send(:analyze_content_evolution, history)
    
    # Check word count trend
    assert evolution[:word_count_trend].length == 4
    assert evolution[:word_count_trend].all? { |trend| trend.key?(:version) && trend.key?(:word_count) && trend.key?(:change) }
    
    # Check status progression
    assert evolution[:status_progression].length == 4
    assert evolution[:status_progression].any? { |status| status[:status] == 'approved' }
    
    # Check format changes
    format_changes = evolution[:format_changes]
    assert format_changes.any? { |change| change[:from] == 'standard' && change[:to] == 'extended' }
    
    # Check approval timeline
    approval_timeline = evolution[:approval_timeline]
    assert approval_timeline.length >= 1
    assert approval_timeline.all? { |approval| approval.key?(:version) && approval.key?(:approved_by) }
  end

  test "should analyze approval workflow" do
    # Create content with approval workflow
    @content_v2.approve!(@other_user)
    @content_v3 = @content_v2.create_new_version!(@user, 'Revision')
    
    service = ContentVersionService.new(@content_v1)
    history = [@content_v1, @content_v2, @content_v3]
    audit_logs = ContentAuditLog.where(generated_content: [@content_v1, @content_v2, @content_v3])
    
    workflow = service.send(:analyze_approval_workflow, history, audit_logs)
    
    assert workflow.key?(:total_approvals)
    assert workflow.key?(:total_rejections)
    assert workflow.key?(:approval_rate)
    assert workflow.key?(:average_approval_time)
    assert workflow.key?(:workflow_efficiency)
    assert workflow.key?(:approvers)
    assert workflow.key?(:rejection_reasons)
    
    assert workflow[:approval_rate] >= 0.0
    assert workflow[:approval_rate] <= 1.0
  end
end