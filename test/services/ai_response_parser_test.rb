require "test_helper"

class AiResponseParserTest < ActiveSupport::TestCase
  def setup
    @parser = AiResponseParser.new
  end

  # Configuration tests
  test "should initialize with default settings" do
    parser = AiResponseParser.new
    assert_equal 'text', parser.response_type
    assert_equal false, parser.strict_validation
    assert_nil parser.provider
  end

  test "should validate supported providers" do
    assert_nothing_raised do
      AiResponseParser.new(provider: 'anthropic')
    end

    assert_raises AiResponseParser::UnsupportedProviderError do
      AiResponseParser.new(provider: 'invalid_provider')
    end
  end

  test "should validate supported response types" do
    assert_nothing_raised do
      AiResponseParser.new(response_type: 'json')
    end

    assert_raises AiResponseParser::InvalidResponseError do
      AiResponseParser.new(response_type: 'invalid_type')
    end
  end

  # Anthropic response parsing tests
  test "should parse anthropic messages api response" do
    parser = AiResponseParser.new(provider: 'anthropic', response_type: 'text')
    
    anthropic_response = {
      'content' => [
        { 'type' => 'text', 'text' => 'Hello from Anthropic!' }
      ],
      'usage' => { 'input_tokens' => 10, 'output_tokens' => 5 },
      'model' => 'claude-3-sonnet',
      'role' => 'assistant',
      'stop_reason' => 'end_turn'
    }

    result = parser.parse(anthropic_response)

    assert result[:content] == 'Hello from Anthropic!'
    assert_equal 'anthropic', result[:provider]
    assert_equal 'text', result[:response_type]
    assert result[:metadata][:usage]
    assert result[:metadata][:model]
  end

  test "should parse anthropic legacy completion response" do
    parser = AiResponseParser.new(provider: 'anthropic')
    
    anthropic_response = {
      'completion' => 'This is a completion response',
      'model' => 'claude-2',
      'stop_reason' => 'stop_sequence'
    }

    result = parser.parse(anthropic_response)

    assert result[:content] == 'This is a completion response'
    assert_equal 'anthropic', result[:provider]
  end

  # OpenAI response parsing tests
  test "should parse openai chat completion response" do
    parser = AiResponseParser.new(provider: 'openai', response_type: 'text')
    
    openai_response = {
      'choices' => [
        {
          'message' => {
            'role' => 'assistant',
            'content' => 'Hello from OpenAI!'
          },
          'finish_reason' => 'stop'
        }
      ],
      'usage' => { 'prompt_tokens' => 8, 'completion_tokens' => 4, 'total_tokens' => 12 },
      'model' => 'gpt-3.5-turbo'
    }

    result = parser.parse(openai_response)

    assert result[:content] == 'Hello from OpenAI!'
    assert_equal 'openai', result[:provider]
    assert result[:metadata][:usage]
    assert result[:metadata][:model]
  end

  test "should parse openai completion with function call" do
    parser = AiResponseParser.new(provider: 'openai')
    
    openai_response = {
      'choices' => [
        {
          'message' => {
            'role' => 'assistant',
            'content' => 'I need to call a function',
            'function_call' => {
              'name' => 'test_function',
              'arguments' => '{"param": "value"}'
            }
          },
          'finish_reason' => 'function_call'
        }
      ]
    }

    result = parser.parse(openai_response)

    assert result[:content] == 'I need to call a function'
    assert result[:metadata][:function_call]
    assert_equal 'test_function', result[:metadata][:function_call]['name']
  end

  # Google response parsing tests  
  test "should parse google ai response" do
    parser = AiResponseParser.new(provider: 'google', response_type: 'text')
    
    google_response = {
      'candidates' => [
        {
          'content' => {
            'parts' => [
              { 'text' => 'Hello from Google AI!' }
            ]
          },
          'finishReason' => 'STOP',
          'safetyRatings' => []
        }
      ],
      'usageMetadata' => { 'promptTokenCount' => 6, 'candidatesTokenCount' => 4 }
    }

    result = parser.parse(google_response)

    assert result[:content] == 'Hello from Google AI!'
    assert_equal 'google', result[:provider]
    assert result[:metadata][:usage]
    assert result[:metadata][:safety_ratings]
  end

  # Generic response parsing tests
  test "should parse plain text response" do
    parser = AiResponseParser.new(response_type: 'text')
    
    result = parser.parse("Just plain text response")

    assert result[:content] == 'Just plain text response'
    assert_equal 'text', result[:response_type]
  end

  test "should parse hash response" do
    parser = AiResponseParser.new
    
    hash_response = { 'content' => 'Hash content', 'extra' => 'metadata' }
    result = parser.parse(hash_response)

    assert result[:content] == 'Hash content'
    assert result[:metadata]['extra'] == 'metadata'
  end

  # JSON content extraction tests
  test "should extract json content from markdown code block" do
    parser = AiResponseParser.new(response_type: 'json')
    
    content_with_json = <<~TEXT
      Here's the JSON response:
      
      ```json
      {"title": "Test Campaign", "budget": 5000}
      ```
      
      Hope this helps!
    TEXT

    result = parser.parse(content_with_json)

    assert result[:content].is_a?(Hash)
    assert_equal 'Test Campaign', result[:content]['title']
    assert_equal 5000, result[:content]['budget']
  end

  test "should extract json from plain text" do
    parser = AiResponseParser.new(response_type: 'json')
    
    content_with_json = 'The data is {"status": "success", "count": 42} for your reference.'

    result = parser.parse(content_with_json)

    assert result[:content].is_a?(Hash)
    assert_equal 'success', result[:content]['status']
    assert_equal 42, result[:content]['count']
  end

  # Structured data extraction tests
  test "should extract campaign plan structure" do
    parser = AiResponseParser.new(response_type: 'campaign_plan')
    
    campaign_content = <<~TEXT
      Title: Summer Marketing Campaign
      
      Objective: Increase brand awareness by 25%
      
      Target Audience: Young adults aged 18-35
      
      Budget Allocation: $10,000 for digital ads
      
      Timeline: 3 months starting June 1st
      
      Channels: Social media, email, web
      
      Key Messages: Fun, trendy, affordable
      
      Success Metrics: Engagement rate, conversion rate
    TEXT

    result = parser.parse(campaign_content)

    campaign_plan = result[:content]
    assert campaign_plan.is_a?(Hash)
    assert_equal 'Summer Marketing Campaign', campaign_plan[:title]
    assert_equal 'Increase brand awareness by 25%', campaign_plan[:objective]
    assert_equal 'Young adults aged 18-35', campaign_plan[:target_audience]
  end

  test "should extract brand analysis structure" do
    parser = AiResponseParser.new(response_type: 'brand_analysis')
    
    brand_content = <<~TEXT
      Brand Voice: Professional and approachable
      
      Brand Values: Innovation, quality, customer focus
      
      Competitive Advantages:
      - Superior technology
      - Excellent customer service
      - Competitive pricing
      
      Content Opportunities:
      - Educational content
      - Customer success stories
      - Product demonstrations
    TEXT

    result = parser.parse(brand_content)

    analysis = result[:content]
    assert analysis.is_a?(Hash)
    assert_equal 'Professional and approachable', analysis[:brand_voice]
    assert analysis[:competitive_advantages].is_a?(Array)
    assert_includes analysis[:competitive_advantages], 'Superior technology'
  end

  # Content generation extraction tests
  test "should extract social media content" do
    parser = AiResponseParser.new(response_type: 'content_generation')
    
    social_content = <<~TEXT
      🌟 Exciting news! Our summer sale is here! Save up to 50% on all items. 
      Don't miss out on these amazing deals! #SummerSale #Savings @YourBrand
      
      Call to Action: Shop now at our website
      
      Hashtags: #sale #summer #deals #fashion
      
      Mentions: @influencer @partner
    TEXT

    result = parser.parse(social_content, content_type: 'social_media')

    content = result[:content]
    assert content.is_a?(Hash)
    assert content[:hashtags].include?('#SummerSale')
    assert content[:mentions].include?('@YourBrand')
  end

  # Error handling tests
  test "should handle empty content gracefully" do
    result = @parser.parse("")

    assert_nil result
  end

  test "should handle nil content gracefully" do
    result = @parser.parse(nil)

    assert_nil result
  end

  test "should handle parsing errors gracefully" do
    parser = AiResponseParser.new(response_type: 'json')
    
    result = parser.parse("invalid json content")

    assert_equal 'error', result[:response_type]
    assert result[:error]
    assert result[:error][:type]
  end

  # Batch parsing tests
  test "should parse batch of responses" do
    responses = [
      "First response",
      "Second response", 
      { 'content' => 'Third response' }
    ]

    results = @parser.parse_batch(responses)

    assert_equal 3, results.length
    assert results[0][:content] == 'First response'
    assert results[1][:content] == 'Second response'
    assert results[2][:content] == 'Third response'
  end

  test "should handle batch parsing errors" do
    parser = AiResponseParser.new(response_type: 'json', strict_validation: true)
    
    responses = [
      '{"valid": "json"}',
      'invalid json'
    ]

    results = parser.parse_batch(responses)

    assert_equal 2, results.length
    assert results[0][:success] != false
    assert results[1][:success] == false
    assert results[1][:error]
  end

  # Provider detection tests
  test "should detect anthropic responses" do
    anthropic_response = { 'content' => [{ 'text' => 'test' }] }
    
    assert @parser.can_parse?(anthropic_response)
  end

  test "should detect openai responses" do
    openai_response = { 'choices' => [{ 'message' => { 'content' => 'test' } }] }
    
    assert @parser.can_parse?(openai_response)
  end

  test "should detect google responses" do
    google_response = { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'test' }] } }] }
    
    assert @parser.can_parse?(google_response)
  end

  # Strict validation tests
  test "should validate json structure when strict validation enabled" do
    parser = AiResponseParser.new(response_type: 'json', strict_validation: true)
    
    assert_raises AiResponseParser::StructureValidationError do
      parser.parse("not valid json at all")
    end
  end

  test "should validate campaign plan structure when strict validation enabled" do
    parser = AiResponseParser.new(response_type: 'campaign_plan', strict_validation: true)
    
    # Missing required fields should raise error
    assert_raises AiResponseParser::StructureValidationError do
      parser.parse("Title: Test Campaign")  # Missing objective and target_audience
    end
  end

  # Format detection tests
  test "should detect original format correctly" do
    parser = AiResponseParser.new

    json_result = parser.parse({ 'test' => 'data' })
    assert_equal 'json', json_result[:original_format]

    text_result = parser.parse('plain text')
    assert_equal 'text', text_result[:original_format]

    markdown_result = parser.parse("# Title\n\nContent with ```code```")
    assert_equal 'markdown', markdown_result[:original_format]
  end

  private

  def sample_anthropic_response
    {
      'content' => [
        { 'type' => 'text', 'text' => 'Sample Anthropic response content' }
      ],
      'usage' => { 'input_tokens' => 10, 'output_tokens' => 8 },
      'model' => 'claude-3-sonnet',
      'stop_reason' => 'end_turn'
    }
  end

  def sample_openai_response
    {
      'choices' => [
        {
          'message' => {
            'role' => 'assistant',
            'content' => 'Sample OpenAI response content'
          },
          'finish_reason' => 'stop'
        }
      ],
      'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 8, 'total_tokens' => 18 },
      'model' => 'gpt-3.5-turbo'
    }
  end
end