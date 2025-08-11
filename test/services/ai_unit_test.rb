require "minitest/autorun"

# Load just what we need without Rails fixtures
require_relative "../../app/services/ai_response_parser"
require_relative "../../app/services/ai_content_validator"
require_relative "../../app/services/ai_content_moderator"
require_relative "../../app/services/ai_response_transformer"

class AiUnitTest < Minitest::Test
  def test_ai_response_parser_basic_functionality
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
  end

  def test_ai_content_validator_basic_functionality
    validator = AiContentValidator.new(validation_types: ['quality'])
    
    good_content = "This is high-quality marketing content with clear value propositions and professional language."
    result = validator.validate(good_content)
    
    assert_equal 'pass', result[:overall_status]
    assert result[:validation_results].any? { |r| r[:type] == 'quality' }
  end

  def test_ai_content_moderator_basic_functionality
    moderator = AiContentModerator.new(enabled_categories: ['profanity'])
    
    profane_content = "This damn product is shit quality"
    result = moderator.moderate(profane_content)
    
    assert result[:moderation_results].any? { |r| r[:category] == 'profanity' }
  end

  def test_ai_response_transformer_basic_functionality
    transformer = AiResponseTransformer.new(target_format: 'standard')
    
    content = "Sample marketing content for transformation"
    result = transformer.transform(content)
    
    assert result[:success]
    assert_equal 'standard', result[:transformed_content][:format]
  end
end