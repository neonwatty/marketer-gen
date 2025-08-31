# frozen_string_literal: true

require 'test_helper'

class RealLlmIntegrationTest < ActiveSupport::TestCase
  def setup
    # Temporarily override environment for testing
    @original_env = {
      'LLM_ENABLED' => ENV['LLM_ENABLED'],
      'USE_REAL_LLM' => ENV['USE_REAL_LLM'],
      'OPENAI_API_KEY' => ENV['OPENAI_API_KEY']
    }
    
    # Set test environment
    ENV['LLM_ENABLED'] = 'true'
    ENV['USE_REAL_LLM'] = 'true'
    ENV['OPENAI_API_KEY'] = 'test-api-key'
    
    # Reload configuration
    Rails.application.reload_routes!
    Rails.application.config_for(:llm_service) rescue nil
  end

  def teardown
    # Restore original environment
    @original_env.each { |key, value| ENV[key] = value }
    Rails.application.reload_routes!
  end

  test "service container registers real providers" do
    assert LlmServiceContainer.registered?(:mock)
    assert LlmServiceContainer.registered?(:openai)
    assert LlmServiceContainer.registered?(:real)
  end

  test "service container returns correct service type based on configuration" do
    # Test mock service (should work without API key when not enabled)
    with_llm_config(enabled: false) do
      service = LlmServiceContainer.get(:mock)
      assert_instance_of MockLlmService, service
    end
  end

  test "OpenAI provider can be instantiated with configuration" do
    config = {
      api_key: 'test-key',
      model: 'gpt-4o-mini',
      max_tokens: 1000,
      temperature: 0.7
    }
    
    provider = LlmProviders::OpenaiProvider.new(config)
    assert_equal 'openai', provider.provider_name
    assert_equal config, provider.config
  end

  test "service container can get real OpenAI provider" do
    # Mock successful provider creation
    mock_provider = Object.new
    LlmProviders::OpenaiProvider.stubs(:new).returns(mock_provider)
    
    # Test that we can get the OpenAI provider
    with_openai_config_enabled do
      provider = LlmServiceContainer.get(:openai)
      assert_not_nil provider
    end
  end

  test "LLM service helper returns correct service" do
    # Create a test controller instance
    controller = ApplicationController.new
    
    with_llm_config(enabled: true, use_real_service: false) do
      service = controller.send(:llm_service)
      assert_instance_of MockLlmService, service
    end
  end

  test "brand context integration works with real provider" do
    brand_context = {
      voice: "professional",
      tone: "authoritative", 
      keywords: ["innovation", "excellence"],
      style: { emoji: false }
    }

    params = {
      platform: "linkedin",
      tone: "professional",
      topic: "product launch",
      brand_context: brand_context
    }

    provider = LlmProviders::OpenaiProvider.new({ api_key: 'test-key' })
    prompt = provider.send(:build_social_media_prompt, params)

    assert_includes prompt, "Brand Voice: professional"
    assert_includes prompt, "Brand Tone: authoritative"
    assert_includes prompt, "Key Messages: innovation, excellence"
  end

  private

  def with_llm_config(enabled: true, use_real_service: false, fallback_enabled: true)
    # Temporarily override configuration
    original_config = Rails.application.config.llm_feature_flags.dup
    
    Rails.application.config.llm_feature_flags.merge!(
      enabled: enabled,
      use_real_service: use_real_service,
      fallback_enabled: fallback_enabled
    )

    Rails.application.config.llm_service_type = if enabled && use_real_service
                                                  :real
                                                else
                                                  :mock
                                                end

    yield
  ensure
    # Restore original configuration
    Rails.application.config.llm_feature_flags = original_config
  end

  def with_openai_config_enabled
    # Temporarily enable OpenAI configuration
    original_providers = Rails.application.config.llm_providers.dup
    
    Rails.application.config.llm_providers[:openai].merge!(
      enabled: true,
      api_key: 'test-api-key'
    )
    
    yield
  ensure
    Rails.application.config.llm_providers = original_providers
  end
end