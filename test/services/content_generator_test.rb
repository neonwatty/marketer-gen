require 'test_helper'

class ContentGeneratorTest < ActiveSupport::TestCase
  setup do
    # Mock AI service to avoid external API calls during testing
    @mock_ai_service = Minitest::Mock.new
    
    # Initialize generator with mocked AI service
    @generator = ContentGenerator.new(ai_service: @mock_ai_service)
  end

  test "should initialize with registry" do
    assert_not_nil @generator.registry
    assert_instance_of ContentGeneratorRegistry, @generator.registry
  end

  test "should generate social media content" do
    # Setup mock response
    @mock_ai_service.expect :generate_content_for_channel, 
      "Check out our amazing new product! Perfect for busy professionals. #productivity #innovation",
      ['social_media', String, Hash]

    # Create request
    request = ContentRequest.new(
      channel_type: 'social_media',
      content_type: 'promotional',
      prompt: 'Promote our new productivity app',
      brand_context: {
        name: 'ProductivePro',
        industry: 'software',
        voice: 'professional yet friendly'
      },
      target_audience: {
        demographics: 'working professionals age 25-45'
      }
    )
    
    request.set_social_media_constraints(platform: 'twitter')

    # Generate content (will use mock)
    response = @generator.generate_content(request)

    # Verify response
    assert_instance_of ContentResponse, response
    assert_equal 'social_media', response.channel_type
    assert_equal 'promotional', response.content_type
    assert_not_empty response.content

    @mock_ai_service.verify
  end

  test "should validate content request" do
    # Test invalid request
    invalid_request = ContentRequest.new(
      channel_type: '', # Missing required field
      content_type: 'promotional'
    )

    assert_raises ContentGeneratorBase::InvalidContentRequestError do
      @generator.generate_content(invalid_request)
    end
  end

  test "should support multiple channel types" do
    registry = @generator.registry
    
    # Check that our main adapters are supported
    assert registry.supports_channel?('social_media'), "Should support social_media"
    assert registry.supports_channel?('email'), "Should support email"
    assert registry.supports_channel?('ads'), "Should support ads"
  end

  test "should provide health status" do
    health_status = @generator.health_status
    
    assert_includes health_status, :status
    assert_includes health_status, :adapters
    assert_includes health_status, :statistics
  end
end