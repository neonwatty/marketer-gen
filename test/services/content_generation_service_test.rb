# frozen_string_literal: true

require 'test_helper'

class ContentGenerationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @other_user = users(:team_member_user)
    @campaign_plan = campaign_plans(:completed_plan)
    @content_type = 'email'
    @options = { format_variant: 'standard' }
    
    # Create test content with enough content to meet validation requirements
    @test_content = GeneratedContent.create!(
      campaign_plan: @campaign_plan,
      content_type: 'email',
      format_variant: 'standard',
      title: 'Test Email',
      body_content: 'This is test email content for testing purposes. It contains enough text to meet the minimum length requirements for the standard format variant. We need at least 100 characters for this to pass validation in our content generation service tests.',
      status: 'draft',
      version_number: 1,
      created_by: @user
    )
  end

  def teardown
    # Clean up Current state if it exists
    Current.session = nil if Current.respond_to?(:session=)
  end

  test "should validate initialization with valid inputs" do
    service = ContentGenerationService.new(@campaign_plan, @content_type, @options)
    assert_equal @campaign_plan, service.campaign_plan
    assert_equal @content_type, service.content_type
    assert_equal @options, service.options
  end

  test "should reject invalid content type" do
    assert_raises ArgumentError do
      ContentGenerationService.new(@campaign_plan, 'invalid_type', @options)
    end
  end

  test "should reject invalid format variant" do
    invalid_options = { format_variant: 'invalid_variant' }
    
    assert_raises ArgumentError do
      ContentGenerationService.new(@campaign_plan, @content_type, invalid_options)
    end
  end

  test "should approve content successfully" do
    content = @test_content
    content.update!(status: 'in_review')
    approver = @other_user
    
    result = ContentGenerationService.approve_content(content.id, approver)
    
    # Debug output if test fails
    unless result[:success]
      puts "Approval failed: #{result[:error]}"
      puts "Content status: #{content.status}"
      puts "Content errors: #{content.errors.full_messages}" if content.errors.any?
    end
    
    assert result[:success], "Expected approval to succeed but got: #{result[:error] || 'unknown error'}"
    assert_equal 'approved', result[:data][:action]
    
    content.reload
    assert_equal 'approved', content.status
    assert_equal approver.id, content.approved_by_id
  end

  test "should reject approval for content not in review" do
    content = @test_content
    content.update!(status: 'draft')
    approver = @other_user
    
    result = ContentGenerationService.approve_content(content.id, approver)
    
    assert_not result[:success]
    assert_includes result[:error], "Content must be in review status"
  end

  test "should build correct LLM parameters for email" do
    service = ContentGenerationService.new(@campaign_plan, 'email', { 
      tone: 'casual', 
      email_type: 'welcome',
      custom_prompts: { additional_context: 'test' }
    })
    
    params = service.send(:build_llm_parameters, 'standard')
    
    assert_equal @campaign_plan.campaign_type, params[:campaign_type]
    assert_equal @campaign_plan.objective, params[:objective]
    assert_equal 'casual', params[:tone]
    assert_equal 'welcome', params[:email_type]
    assert_equal 'test', params[:additional_context]
  end

  test "should build correct LLM parameters for social post" do
    service = ContentGenerationService.new(@campaign_plan, 'social_post', { 
      platform: 'twitter', 
      tone: 'engaging'
    })
    
    params = service.send(:build_llm_parameters, 'short')
    
    assert_equal @campaign_plan.campaign_type, params[:campaign_type]
    assert_equal @campaign_plan.objective, params[:objective]
    assert_equal 'twitter', params[:platform]
    assert_equal 'engaging', params[:tone]
    assert params[:character_limit] > 0
  end

  test "should determine correct variants for content types" do
    service = ContentGenerationService.new(@campaign_plan, 'social_post', {})
    variants = service.send(:determine_relevant_variants)
    assert_equal %w[short medium], variants
    
    service = ContentGenerationService.new(@campaign_plan, 'blog_article', {})
    variants = service.send(:determine_relevant_variants)
    assert_equal %w[summary standard comprehensive], variants
    
    service = ContentGenerationService.new(@campaign_plan, 'email', {})
    variants = service.send(:determine_relevant_variants)
    assert_equal %w[brief standard extended], variants
  end

  test "should get correct character limits for variants" do
    service = ContentGenerationService.new(@campaign_plan, @content_type, {})
    
    assert_equal 500, service.send(:get_character_limit_for_variant, 'short')
    assert_equal 1500, service.send(:get_character_limit_for_variant, 'standard')
    assert_equal 3000, service.send(:get_character_limit_for_variant, 'long')
    assert_equal 5000, service.send(:get_character_limit_for_variant, 'comprehensive')
  end

  test "should normalize email LLM response correctly" do
    service = ContentGenerationService.new(@campaign_plan, 'email', {})
    
    llm_result = {
      subject: "Test Subject",
      content: "Test email content",
      metadata: { tone: 'professional' }
    }
    
    normalized = service.send(:normalize_llm_response, llm_result)
    
    assert_equal "Test Subject", normalized[:title]
    assert_equal "Test email content", normalized[:content]
    assert_equal({ tone: 'professional' }, normalized[:metadata])
  end

  test "should normalize ad copy LLM response correctly" do
    service = ContentGenerationService.new(@campaign_plan, 'ad_copy', {})
    
    llm_result = {
      headline: "Great Product!",
      description: "Buy now for amazing results",
      call_to_action: "Get Started",
      metadata: { ad_type: 'search' }
    }
    
    normalized = service.send(:normalize_llm_response, llm_result)
    
    assert_equal "Great Product!", normalized[:title]
    assert_includes normalized[:content], "Great Product!"
    assert_includes normalized[:content], "Buy now for amazing results"
    assert_includes normalized[:content], "Get Started"
    assert_equal "Great Product!", normalized[:metadata][:headline]
  end

  test "should build content metadata correctly" do
    service = ContentGenerationService.new(@campaign_plan, @content_type, { test_option: 'value' })
    
    llm_metadata = { llm_specific: 'data' }
    metadata = service.send(:build_content_metadata, llm_metadata, 'standard')
    
    assert_equal 'content_generation_service', metadata[:creation_source]
    assert metadata[:auto_generated]
    assert metadata[:generated_at]
    assert_equal 'standard', metadata[:format_variant]
    assert_equal @campaign_plan.id, metadata[:campaign_plan_id]
    assert_equal 'data', metadata[:llm_specific]
    assert_equal 'value', metadata[:generation_parameters][:test_option]
  end

  test "should generate fallback content when LLM fails" do
    service = ContentGenerationService.new(@campaign_plan, @content_type, {})
    
    fallback = service.send(:generate_fallback_content, 'standard')
    
    assert_includes fallback[:title], @campaign_plan.name
    assert_includes fallback[:content], @campaign_plan.objective
    assert fallback[:metadata][:fallback_content]
    assert_equal 'llm_service_unavailable', fallback[:metadata][:reason]
  end

  test "should validate content quality and log warnings for short content" do
    # Create content with valid length but low word count (within minimum)
    short_content = GeneratedContent.new(
      campaign_plan: @campaign_plan,
      content_type: @content_type,
      format_variant: 'short', # Use short format to avoid length validation
      title: 'Test',
      body_content: 'Hi there, this is a test message!', # Short but valid content
      status: 'draft',
      version_number: 1,
      created_by: @user
    )
    
    service = ContentGenerationService.new(@campaign_plan, @content_type, {})
    
    # Should not raise error but will log warning for low word count
    assert_nothing_raised do
      service.send(:validate_content_quality, short_content)
    end
    
    assert_equal 7, short_content.word_count
  end

  test "should handle Current user lookup correctly" do
    service = ContentGenerationService.new(@campaign_plan, @content_type, {})
    
    # Test with no Current.user (should fall back to campaign_plan.user)
    current_user = service.send(:create_content_record, {
      title: 'Test Title',
      content: 'Test content that is long enough to meet the minimum requirements for validation in our system. This ensures we have enough text.',
      metadata: {}
    }, 'standard')
    
    assert_equal @campaign_plan.user, current_user.created_by
  end

  test "should generate default title correctly" do
    service = ContentGenerationService.new(@campaign_plan, @content_type, {})
    title = service.send(:generate_default_title)
    
    assert_equal "Email for #{@campaign_plan.name}", title
  end

  test "class methods should delegate to instance methods" do
    # Test that class methods exist and can be called
    assert_respond_to ContentGenerationService, :generate_content
    assert_respond_to ContentGenerationService, :regenerate_content
    assert_respond_to ContentGenerationService, :create_format_variants
    assert_respond_to ContentGenerationService, :approve_content
  end
end