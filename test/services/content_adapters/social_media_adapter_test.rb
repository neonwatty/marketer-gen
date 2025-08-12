require 'test_helper'

class ContentAdapters::SocialMediaAdapterTest < ActiveSupport::TestCase
  setup do
    @mock_ai_service = Minitest::Mock.new
    @adapter = ContentAdapters::SocialMediaAdapter.new(
      ai_service: @mock_ai_service,
      brand_context: {
        name: 'TestBrand',
        industry: 'technology',
        voice: 'professional'
      }
    )
  end

  test "should initialize with correct metadata" do
    assert_equal 'social_media_adapter', @adapter.channel_type
    assert_includes @adapter.supported_content_types, 'post'
    assert_includes @adapter.supported_content_types, 'promotional'
  end

  test "should validate social media request" do
    # Valid request
    valid_request = ContentRequest.new(
      channel_type: 'social_media',
      content_type: 'post',
      prompt: 'Test content',
      brand_context: { name: 'Test' },
      channel_metadata: { platform: 'twitter' }
    )

    assert_nothing_raised do
      @adapter.send(:validate_social_media_request!, valid_request)
    end

    # Invalid request - no platform
    invalid_request = ContentRequest.new(
      channel_type: 'social_media',
      content_type: 'post',
      prompt: 'Test content',
      brand_context: { name: 'Test' },
      channel_metadata: { platform: 'invalid_platform' }
    )

    assert_raises ContentAdapters::BaseChannelAdapter::InvalidContentRequestError do
      @adapter.send(:validate_social_media_request!, invalid_request)
    end
  end

  test "should generate content for different platforms" do
    @mock_ai_service.expect :generate_content_for_channel,
      "CONTENT: Exciting news from TestBrand! Check out our latest innovation.\nHASHTAGS: #innovation #tech\nCTA: Learn more",
      ['social_media', String, Hash]

    request = ContentRequest.new(
      channel_type: 'social_media',
      content_type: 'announcement',
      prompt: 'Announce our latest product',
      brand_context: { name: 'TestBrand', industry: 'technology' },
      channel_metadata: { platform: 'twitter' },
      target_audience: { demographics: 'tech enthusiasts' }
    )

    response = @adapter.generate_content(request)

    assert_instance_of ContentResponse, response
    assert_equal 'social_media', response.channel_type
    assert_not_empty response.content
    assert_not_empty response.hashtags

    @mock_ai_service.verify
  end

  test "should validate content length for platforms" do
    request = ContentRequest.new(
      channel_type: 'social_media',
      content_type: 'post',
      brand_context: { name: 'Test' },
      channel_metadata: { platform: 'twitter' }
    )

    # Content too long for Twitter
    long_content = "A" * 300
    
    assert_raises ContentAdapters::BaseChannelAdapter::ContentValidationError do
      @adapter.validate_content(long_content, request)
    end

    # Valid length content
    valid_content = "Great content for Twitter! #test"
    
    assert_nothing_raised do
      @adapter.validate_content(valid_content, request)
    end
  end

  test "should extract hashtags and mentions" do
    content = "Check out @testuser's review of our product! #amazing #quality #recommended"
    platform_config = { max_hashtags: 5, max_mentions: 3 }
    
    elements = @adapter.send(:extract_social_elements, content, platform_config)
    
    assert_includes elements[:hashtags], 'amazing'
    assert_includes elements[:hashtags], 'quality'
    assert_includes elements[:hashtags], 'recommended'
    assert_includes elements[:mentions], 'testuser'
  end

  test "should provide optimization suggestions" do
    # Test low engagement content
    performance_data = {
      engagement_rate: 0.01, # Low engagement
      click_rate: 0.005 # Low clicks
    }

    suggestions = @adapter.optimize_content("This is a basic post.", performance_data)
    
    assert suggestions.any? { |s| s[:type] == :engagement }
  end

  test "should support variants generation" do
    @mock_ai_service.expect :generate_content_for_channel,
      "CONTENT: Variant content\nHASHTAGS: #test\nTONE: casual",
      ['social_media', String, Hash]

    request = ContentRequest.new(
      channel_type: 'social_media',
      content_type: 'post',
      prompt: 'Test content',
      brand_context: { name: 'TestBrand' },
      channel_metadata: { platform: 'twitter' }
    )

    assert @adapter.supports_variants?
    
    # This would normally generate multiple variants, but with our simple mock it will just verify the method works
    assert_nothing_raised do
      variants = @adapter.generate_variants(request, count: 1)
      assert_equal 1, variants.size
    end

    @mock_ai_service.verify
  end
end