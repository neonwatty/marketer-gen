require 'test_helper'

class ContentGeneratorTest < ActiveSupport::TestCase
  setup do
    # Create a simple mock AI service
    @mock_ai_service = Class.new do
      def generate_content_for_channel(channel, prompt, options = {})
        "Mock generated content for #{channel}: #{prompt}"
      end
      
      def health_check
        { status: 'healthy', provider: 'mock' }
      end

      def model_name
        'mock-model'
      end
    end.new
    
    # Initialize generator with mocked AI service and basic brand context
    @generator = ContentGenerator.new(
      ai_service: @mock_ai_service,
      brand_context: { name: 'Test Brand', industry: 'technology' }
    )
  end

  test "should initialize with registry" do
    assert_not_nil @generator.registry
    assert_instance_of ContentGeneratorRegistry, @generator.registry
  end

  test "should generate social media content" do
    # Create request - using actual ContentRequest attributes
    request = ContentRequest.new(
      content_type: 'social_media',
      campaign_name: 'Productivity App Launch',
      additional_context: 'Promote our new productivity app',
      brand_context: {
        name: 'ProductivePro',
        industry: 'software',
        voice: 'professional yet friendly'
      },
      platform: 'twitter',
      request_metadata: { platform: :twitter }
    )

    # Generate content (will use mock)
    response = @generator.generate_content(request)

    # Verify response
    assert_not_nil response
    # The response should be a ContentResponse object
    assert_instance_of ContentResponse, response
    assert_equal 'completed', response.generation_status
    assert_not_empty response.generated_content
  end

  test "should validate content request" do
    # Test invalid request - empty content_type
    invalid_request = ContentRequest.new(
      content_type: '', # Missing required field
      campaign_name: 'Test Campaign'
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