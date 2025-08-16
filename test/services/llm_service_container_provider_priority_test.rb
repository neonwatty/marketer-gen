# frozen_string_literal: true

require 'test_helper'

class LlmServiceContainerProviderPriorityTest < ActiveSupport::TestCase
  def setup
    LlmServiceContainer.clear!
    LlmServiceContainer.register(:mock, MockLlmService)
    
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: true,
      fallback_enabled: true
    }
  end

  test "should sort providers by priority" do
    Rails.application.config.llm_providers = {
      provider_a: { api_key: 'key-a', enabled: true, priority: 3 },
      provider_b: { api_key: 'key-b', enabled: true, priority: 1 },
      provider_c: { api_key: 'key-c', enabled: true, priority: 2 }
    }
    
    container = LlmServiceContainer
    available_providers = container.send(:get_available_providers)
    
    # Should be sorted by priority (lower number = higher priority)
    assert_equal [:provider_b, :provider_c, :provider_a], available_providers
  end

  test "should exclude disabled providers" do
    Rails.application.config.llm_providers = {
      provider_a: { api_key: 'key-a', enabled: true, priority: 1 },
      provider_b: { api_key: 'key-b', enabled: false, priority: 2 },
      provider_c: { api_key: nil, enabled: true, priority: 3 }
    }
    
    container = LlmServiceContainer
    available_providers = container.send(:get_available_providers)
    
    # Should only include provider_a (enabled with API key)
    assert_equal [:provider_a], available_providers
  end

  test "should fallback to mock when no providers available" do
    Rails.application.config.llm_providers = {}
    Rails.application.config.llm_fallback_enabled = true
    
    service = LlmServiceContainer.get(:real)
    assert_instance_of MockLlmService, service
  end

  test "should raise error when fallback disabled and no providers" do
    Rails.application.config.llm_providers = {}
    Rails.application.config.llm_fallback_enabled = false
    
    assert_raises(StandardError, "No LLM providers available and fallback disabled") do
      LlmServiceContainer.get(:real)
    end
  end
end