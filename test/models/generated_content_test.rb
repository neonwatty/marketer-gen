require "test_helper"

class GeneratedContentTest < ActiveSupport::TestCase
  # Load only the fixtures we need
  fixtures :users, :campaign_plans
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @generated_content = GeneratedContent.new(
      content_type: 'email',
      title: 'Test Email Campaign',
      body_content: 'This is a test email content with sufficient length to pass validation requirements for standard format. It needs to be at least 100 characters long to meet the minimum content length validation requirements defined in our GeneratedContent model.',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
  end

  test "should be valid with valid attributes" do
    unless @generated_content.valid?
      puts "Validation errors: #{@generated_content.errors.full_messages}"
    end
    assert @generated_content.valid?
  end

  test "should require content_type" do
    @generated_content.content_type = nil
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:content_type], "can't be blank"
  end

  test "should require title" do
    @generated_content.title = nil
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:title], "can't be blank"
  end

  test "should require body_content" do
    @generated_content.body_content = nil
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:body_content], "can't be blank"
  end

  test "should require minimum body_content length" do
    @generated_content.body_content = "short"
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:body_content], "is too short (minimum is 10 characters)"
  end

  test "should validate content_type inclusion" do
    @generated_content.content_type = 'invalid_type'
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:content_type], "is not included in the list"
  end

  test "should validate format_variant inclusion" do
    @generated_content.format_variant = 'invalid_variant'
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:format_variant], "is not included in the list"
  end

  test "should validate status inclusion" do
    @generated_content.status = 'invalid_status'
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:status], "is not included in the list"
  end

  test "should set default version_number to 1" do
    @generated_content.save!
    assert_equal 1, @generated_content.version_number
  end

  test "should set default metadata on create" do
    @generated_content.save!
    assert_not_nil @generated_content.metadata
    assert_equal 'manual', @generated_content.metadata['creation_source']
    assert_equal false, @generated_content.metadata['auto_generated']
  end

  test "should belong to campaign_plan" do
    assert_respond_to @generated_content, :campaign_plan
    assert_equal @campaign_plan, @generated_content.campaign_plan
  end

  test "should belong to created_by user" do
    assert_respond_to @generated_content, :created_by
    assert_equal @user, @generated_content.created_by
  end

  test "should have status methods" do
    assert @generated_content.draft?
    assert_not @generated_content.approved?
    assert_not @generated_content.published?
    assert_not @generated_content.archived?
  end

  test "should calculate word count" do
    @generated_content.body_content = "This is a test with ten words exactly here."
    assert_equal 10, @generated_content.word_count
  end

  test "should calculate character count" do
    content = "Test content"
    @generated_content.body_content = content
    assert_equal content.length, @generated_content.character_count
  end

  test "should calculate estimated read time" do
    # 400 words should take 2 minutes at 200 words per minute
    @generated_content.body_content = ("word " * 400).strip
    assert_equal 2, @generated_content.estimated_read_time
  end

  test "should be original version by default" do
    @generated_content.save!
    assert @generated_content.original_version?
  end

  test "should be latest version by default" do
    @generated_content.save!
    assert @generated_content.latest_version?
  end

  test "should create new version" do
    @generated_content.save!
    new_version = @generated_content.create_new_version!(@user, "Updated content")
    
    assert_equal @generated_content.id, new_version.original_content_id
    assert_equal 2, new_version.version_number
    assert_equal 'draft', new_version.status
    assert_nil new_version.approved_by_id
  end

  test "should submit for review" do
    @generated_content.save!
    result = @generated_content.submit_for_review!(@user)
    
    assert result
    assert @generated_content.in_review?
    assert_not_nil @generated_content.metadata['submitted_for_review_at']
  end

  test "should approve content" do
    @generated_content.status = 'in_review'
    @generated_content.save!
    
    result = @generated_content.approve!(@user)
    
    assert result
    assert @generated_content.approved?
    assert_equal @user, @generated_content.approver
  end

  test "should reject content with reason" do
    @generated_content.status = 'in_review'
    @generated_content.save!
    
    reason = "Content needs improvement"
    result = @generated_content.reject!(@user, reason)
    
    assert result
    assert @generated_content.rejected?
    assert_equal reason, @generated_content.metadata['rejection_reason']
  end

  test "should publish approved content" do
    @generated_content.status = 'approved'
    @generated_content.save!
    
    result = @generated_content.publish!(@user)
    
    assert result
    assert @generated_content.published?
    assert_not_nil @generated_content.metadata['published_at']
  end

  test "should soft delete content" do
    @generated_content.save!
    @generated_content.soft_delete!
    
    assert @generated_content.deleted?
    assert @generated_content.archived?
    assert_not_nil @generated_content.deleted_at
  end

  test "should restore soft deleted content" do
    @generated_content.save!
    @generated_content.soft_delete!
    @generated_content.restore!
    
    assert_not @generated_content.deleted?
    assert @generated_content.draft?
    assert_nil @generated_content.deleted_at
  end

  test "should scope by content type" do
    @generated_content.save!
    
    email_content = GeneratedContent.by_content_type('email')
    assert_includes email_content, @generated_content
    
    blog_content = GeneratedContent.by_content_type('blog_article')
    assert_not_includes blog_content, @generated_content
  end

  test "should scope by status" do
    @generated_content.save!
    
    draft_content = GeneratedContent.by_status('draft')
    assert_includes draft_content, @generated_content
    
    approved_content = GeneratedContent.by_status('approved')
    assert_not_includes approved_content, @generated_content
  end

  test "should search content by title and body" do
    @generated_content.title = "Unique Email Title"
    @generated_content.body_content = "This contains unique keyword somewhere in the text."
    @generated_content.save!
    
    results = GeneratedContent.search_content("unique")
    assert_includes results, @generated_content
    
    results = GeneratedContent.search_content("nonexistent")
    assert_not_includes results, @generated_content
  end

  test "should validate content length by variant" do
    @generated_content.format_variant = 'comprehensive'
    @generated_content.body_content = "Short content"
    
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:body_content], "must be at least 2000 characters for comprehensive format"
  end

  test "should set platform settings" do
    @generated_content.save!
    
    twitter_settings = { character_limit: 280, hashtags: ['#marketing'] }
    @generated_content.set_platform_settings('twitter', twitter_settings)
    
    assert_equal twitter_settings, @generated_content.platform_settings('twitter')
  end

  test "should provide content summary" do
    @generated_content.save!
    summary = @generated_content.content_summary
    
    assert_equal @generated_content.id, summary[:id]
    assert_equal @generated_content.title, summary[:title]
    assert_equal @generated_content.content_type, summary[:content_type]
    assert_equal @user.full_name, summary[:creator]
    assert summary[:is_latest_version]
  end

  test "should not allow self-referential original_content" do
    @generated_content.save!
    @generated_content.original_content_id = @generated_content.id
    
    assert_not @generated_content.valid?
    assert_includes @generated_content.errors[:original_content_id], "cannot reference itself"
  end

  test "should validate version number consistency" do
    @generated_content.save!
    new_version = @generated_content.create_new_version!(@user)
    
    # Try to create another version with the same version number
    duplicate_version = GeneratedContent.new(
      content_type: 'email',
      title: 'Duplicate Version',
      body_content: 'This is a duplicate version test.',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user,
      original_content_id: @generated_content.id,
      version_number: new_version.version_number
    )
    
    assert_not duplicate_version.valid?
    assert_includes duplicate_version.errors[:version_number], "already exists for this content"
  end

  test "should include proper associations in campaign plan" do
    @generated_content.save!
    assert_includes @campaign_plan.generated_contents, @generated_content
  end

  test "should include proper associations in user" do
    @generated_content.save!
    assert_includes @user.created_contents, @generated_content
  end
end
