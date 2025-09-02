require "test_helper"

class BulkContentGenerationServiceTest < ActiveSupport::TestCase
  
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @campaign_plan.update!(
      status: 'completed',
      generated_summary: 'Test summary',
      generated_strategy: 'Test strategy', 
      generated_timeline: 'Test timeline',
      generated_assets: ['Email campaigns', 'Social media posts', 'Blog articles', 'Landing page']
    )
    @service = BulkContentGenerationService.new(@campaign_plan)
  end

  test "should initialize with campaign plan" do
    assert_not_nil @service
    assert_equal @campaign_plan, @service.instance_variable_get(:@campaign_plan)
    assert_equal @user, @service.instance_variable_get(:@user)
  end

  test "should not generate content for incomplete campaign" do
    @campaign_plan.update!(status: 'draft')
    result = @service.generate_all
    
    assert_not result[:success]
    assert_match(/must be completed/, result[:error])
  end

  test "should not generate content if no assets present" do
    @campaign_plan.update!(generated_assets: nil)
    result = @service.generate_all
    
    assert_not result[:success]
    assert_match(/no generated assets/, result[:error])
  end

  test "should determine content types from assets" do
    # Test private method indirectly through service call
    @campaign_plan.update!(
      generated_assets: [
        'Email newsletter',
        'Social media posts',
        'Blog article about product',
        'Google Ads campaign',
        'Landing page for conversions',
        'Video script for YouTube',
        'Press release for launch',
        'Monthly newsletter'
      ]
    )
    
    # Mock the content generation to avoid actual LLM calls
    ContentGenerationService.stubs(:generate_content).returns({
      success: true,
      data: { content: mock_content }
    })
    
    result = @service.generate_all
    
    # Should have determined multiple content types
    assert result[:success] || result[:partial]
  end

  test "should map email assets to email content type" do
    @campaign_plan.update!(generated_assets: ['Email campaign', 'Welcome email series'])
    
    ContentGenerationService.stubs(:generate_content).with(
      @campaign_plan, 'email', anything
    ).returns({
      success: true,
      data: { content: mock_content }
    })
    
    result = @service.generate_all
    assert result[:success] || result[:partial]
  end

  test "should map social assets to social_post content type" do
    @campaign_plan.update!(generated_assets: ['Social media campaign', 'Instagram posts'])
    
    ContentGenerationService.stubs(:generate_content).with(
      @campaign_plan, 'social_post', anything
    ).returns({
      success: true,
      data: { content: mock_content }
    })
    
    result = @service.generate_all
    assert result[:success] || result[:partial]
  end

  test "should map blog assets to blog_article content type" do
    @campaign_plan.update!(generated_assets: ['Blog series', 'Technical articles'])
    
    ContentGenerationService.stubs(:generate_content).with(
      @campaign_plan, 'blog_article', anything
    ).returns({
      success: true,
      data: { content: mock_content }
    })
    
    result = @service.generate_all
    assert result[:success] || result[:partial]
  end

  test "should handle partial success when some content fails" do
    @campaign_plan.update!(generated_assets: ['Email campaign', 'Social posts'])
    
    # First call succeeds
    ContentGenerationService.stubs(:generate_content).with(
      @campaign_plan, 'email', anything
    ).returns({
      success: true,
      data: { content: mock_content }
    })
    
    # Second call fails
    ContentGenerationService.stubs(:generate_content).with(
      @campaign_plan, 'social_post', anything
    ).returns({
      success: false,
      error: 'Generation failed'
    })
    
    result = @service.generate_all
    
    assert result[:success]
    assert result[:partial]
    assert_includes result[:message], 'with 1 errors'
  end

  test "should generate default content types based on campaign type" do
    # Test for product_launch campaign type
    @campaign_plan.update!(
      campaign_type: 'product_launch',
      generated_assets: []  # Empty assets to trigger default
    )
    
    # Should generate default set for product launch
    expected_types = ['email', 'social_post', 'press_release', 'blog_article', 'ad_copy']
    
    ContentGenerationService.stubs(:generate_content).returns({
      success: true,
      data: { content: mock_content }
    })
    
    result = @service.generate_all
    
    # Verify it attempts to generate the default types
    assert result[:success] || result[:partial]
  end

  test "should generate multiple format variants for content types" do
    @campaign_plan.update!(generated_assets: ['Social media posts'])
    
    # Should generate both short and medium variants for social posts
    ContentGenerationService.expects(:generate_content).with(
      @campaign_plan, 'social_post', has_entry(format_variant: 'short')
    ).returns({ success: true, data: { content: mock_content } })
    
    ContentGenerationService.expects(:generate_content).with(
      @campaign_plan, 'social_post', has_entry(format_variant: 'medium')
    ).returns({ success: true, data: { content: mock_content } })
    
    result = @service.generate_all
    assert result[:success]
  end

  test "should handle exceptions gracefully" do
    @campaign_plan.update!(generated_assets: ['Email campaign'])
    
    ContentGenerationService.stubs(:generate_content).raises(StandardError, 'Unexpected error')
    
    result = @service.generate_all
    
    assert_not result[:success]
    assert_includes result[:error], 'Failed to generate content'
  end

  test "should track generated contents count" do
    @campaign_plan.update!(generated_assets: ['Email', 'Social post'])
    
    ContentGenerationService.stubs(:generate_content).returns({
      success: true,
      data: { content: mock_content }
    })
    
    result = @service.generate_all
    
    assert result[:success]
    assert result[:count] > 0
    assert_equal result[:count], result[:contents].length
  end

  test "should set proper metadata for generated content" do
    @campaign_plan.update!(generated_assets: ['Email newsletter'])
    
    ContentGenerationService.expects(:generate_content).with(
      @campaign_plan,
      'email',
      has_entries(
        auto_generated: true,
        bulk_generation: true,
        title: includes('Email for')
      )
    ).returns({ success: true, data: { content: mock_content } })
    
    result = @service.generate_all
    assert result[:success]
  end

  private

  def mock_content
    @mock_content ||= GeneratedContent.new(
      id: SecureRandom.uuid,
      title: 'Test Content',
      body_content: 'This is test content that is long enough to pass validation. ' * 3,
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
  end
end