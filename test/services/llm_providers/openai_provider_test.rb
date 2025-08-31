# frozen_string_literal: true

require 'test_helper'

class LlmProviders::OpenaiProviderTest < ActiveSupport::TestCase
  def setup
    @config = {
      api_key: 'test-api-key',
      model: 'gpt-4o-mini',
      max_tokens: 100,
      temperature: 0.7,
      timeout: 10
    }
    @provider = LlmProviders::OpenaiProvider.new(@config)
  end

  test "initializes with correct configuration" do
    assert_equal 'openai', @provider.provider_name
    assert_equal @config, @provider.config
  end

  test "validates configuration on initialization" do
    assert_raises(ArgumentError, "API key missing") do
      LlmProviders::OpenaiProvider.new({ api_key: nil })
    end
    
    assert_raises(ArgumentError, "Invalid timeout") do
      LlmProviders::OpenaiProvider.new({ api_key: 'test-key', timeout: 0 })
    end
  end

  test "builds social media prompt correctly" do
    params = {
      platform: 'twitter',
      tone: 'casual',
      topic: 'new product launch',
      character_limit: 280,
      brand_context: { voice: 'friendly', keywords: ['innovation'] }
    }
    
    prompt = @provider.send(:build_social_media_prompt, params)
    
    assert_includes prompt, 'twitter'
    assert_includes prompt, 'casual'
    assert_includes prompt, 'new product launch'
    assert_includes prompt, '280'
    assert_includes prompt, 'friendly'
    assert_includes prompt, 'innovation'
    assert_includes prompt, 'JSON'
  end

  test "parses social media response correctly" do
    json_response = {
      "content" => "Exciting news! Our new product is here 🚀 #innovation",
      "metadata" => {
        "character_count" => 45,
        "hashtags_used" => ["#innovation"],
        "tone_confidence" => 0.95
      }
    }.to_json

    result = @provider.send(:parse_social_media_response, json_response)
    
    assert_equal "Exciting news! Our new product is here 🚀 #innovation", result[:content]
    assert_equal 45, result[:metadata]["character_count"]
    assert_includes result[:metadata]["hashtags_used"], "#innovation"
    assert_equal 'openai', result[:metadata][:service]
  end

  test "handles malformed JSON response with fallback" do
    malformed_response = "This is not JSON but still good content"
    
    result = @provider.send(:parse_social_media_response, malformed_response)
    
    assert_equal "This is not JSON but still good content", result[:content]
    assert result[:metadata][:fallback_parsing]
    assert_equal 'openai', result[:metadata][:service]
  end

  test "builds email prompt correctly" do
    params = {
      email_type: 'welcome',
      subject: 'welcome to our platform',
      tone: 'friendly'
    }
    
    prompt = @provider.send(:build_email_prompt, params)
    
    assert_includes prompt, 'welcome'
    assert_includes prompt, 'welcome to our platform'
    assert_includes prompt, 'friendly'
    assert_includes prompt, 'JSON'
  end

  test "parses email response correctly" do
    json_response = {
      "subject" => "Welcome to our amazing platform!",
      "content" => "We're excited to have you join us...",
      "metadata" => {
        "email_type" => "welcome",
        "word_count" => 50,
        "tone" => "friendly"
      }
    }.to_json

    result = @provider.send(:parse_email_response, json_response)
    
    assert_equal "Welcome to our amazing platform!", result[:subject]
    assert_equal "We're excited to have you join us...", result[:content]
    assert_equal "welcome", result[:metadata]["email_type"]
    assert_equal 'openai', result[:metadata][:service]
  end

  test "generates fallback response when needed" do
    result = @provider.send(:generate_fallback_response, 'social_media', { platform: 'twitter' })
    
    assert_equal "Generated social_media content", result[:content]
    assert result[:metadata][:fallback_used]
    assert_equal 'openai', result[:metadata][:provider]
    assert_equal "llm_service_unavailable", result[:metadata][:reason]
  end

  test "builds brand context correctly" do
    brand_context = {
      voice: 'professional',
      tone: 'authoritative',
      keywords: ['innovation', 'excellence'],
      style: { emoji: false, formality: 'formal' }
    }
    
    result = @provider.send(:build_brand_context, brand_context)
    
    assert_includes result, 'Brand Voice: professional'
    assert_includes result, 'Brand Tone: authoritative'
    assert_includes result, 'Key Messages: innovation, excellence'
    assert_includes result, 'Style Guidelines:'
  end

  test "extracts JSON from mixed content" do
    mixed_content = "Here's your content:\n\n{\"content\": \"Hello world\"}\n\nHope this helps!"
    
    result = @provider.send(:extract_json, mixed_content)
    
    assert_equal '{"content": "Hello world"}', result
  end

  test "handles empty brand context" do
    result = @provider.send(:build_brand_context, {})
    assert_equal "", result
    
    result = @provider.send(:build_brand_context, nil)
    assert_equal "", result
  end
end