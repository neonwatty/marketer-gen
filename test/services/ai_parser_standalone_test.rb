require "test_helper"

# Standalone test that doesn't depend on fixtures
class AiParserStandaloneTest < ActiveSupport::TestCase
  def setup
    # No fixtures needed
  end

  test "AiResponseParser should initialize and parse basic content" do
    parser = AiResponseParser.new(provider: 'anthropic')
    
    mock_response = {
      content: [
        { type: 'text', text: 'Great marketing content!' }
      ],
      usage: { input_tokens: 10, output_tokens: 5 }
    }
    
    result = parser.parse(mock_response)
    
    assert result[:success]
    assert_equal 'Great marketing content!', result[:content]
    assert_equal 'anthropic', result[:metadata][:provider]
    assert_equal 10, result[:metadata][:input_tokens]
  end

  test "AiContentValidator should validate quality" do
    validator = AiContentValidator.new(validation_types: ['quality'])
    
    good_content = "This is high-quality marketing content with clear value propositions and professional language."
    result = validator.validate(good_content)
    
    assert_equal 'pass', result[:overall_status]
    assert result[:validation_results].any? { |r| r[:type] == 'quality' }
  end

  test "AiContentModerator should detect profanity" do
    moderator = AiContentModerator.new(enabled_categories: ['profanity'])
    
    profane_content = "This damn product is shit quality"
    result = moderator.moderate(profane_content)
    
    assert result[:moderation_results].any? { |r| r[:category] == 'profanity' }
    assert ['flag', 'block'].include?(result[:overall_action])
  end

  test "AiResponseTransformer should transform to standard format" do
    transformer = AiResponseTransformer.new(target_format: 'standard')
    
    content = "Sample marketing content for transformation"
    result = transformer.transform(content)
    
    assert result[:success]
    assert_equal 'standard', result[:transformed_content][:format]
    assert result[:transformed_content][:content]
  end

  test "All services should handle errors gracefully" do
    # Test parser with invalid input
    parser = AiResponseParser.new(provider: 'openai')
    result = parser.parse(nil)
    refute result[:success]
    assert result[:error]

    # Test validator with empty content
    validator = AiContentValidator.new
    result = validator.validate("")
    assert_equal 'error', result[:overall_status]

    # Test moderator with nil content
    moderator = AiContentModerator.new
    result = moderator.moderate(nil)
    assert_equal 'error', result[:overall_action]

    # Test transformer with nil content
    transformer = AiResponseTransformer.new
    result = transformer.transform(nil)
    refute result[:success]
  end

  test "Integration: Full pipeline processing" do
    # Simulate the full pipeline without database dependencies
    
    # 1. Parse AI response
    parser = AiResponseParser.new(provider: 'anthropic')
    ai_response = {
      content: [{ type: 'text', text: 'Check out our amazing summer sale! Save up to 50% on all items. #SummerSale' }],
      usage: { input_tokens: 20, output_tokens: 15 }
    }
    parsed = parser.parse(ai_response)
    
    # 2. Validate content
    validator = AiContentValidator.new(validation_types: ['quality', 'appropriateness'])
    validation = validator.validate(parsed[:content])
    
    # 3. Moderate content
    moderator = AiContentModerator.new
    moderation = moderator.moderate(parsed[:content])
    
    # 4. Transform content
    transformer = AiResponseTransformer.new(target_format: 'social_media')
    transformation = transformer.transform(parsed[:content])
    
    # Verify pipeline results
    assert parsed[:success]
    assert_equal 'pass', validation[:overall_status]
    assert_equal 'allow', moderation[:overall_action]
    assert transformation[:success]
    
    # Check that social media transformation extracted hashtags
    if transformation[:transformed_content][:social_media_content]
      hashtags = transformation[:transformed_content][:social_media_content][:hashtags]
      assert hashtags.is_a?(Array)
      assert_includes hashtags, '#SummerSale'
    end
  end
end