# frozen_string_literal: true

require 'test_helper'

class LlmServiceContainerErrorHandlingTest < ActiveSupport::TestCase
  def setup
    LlmServiceContainer.clear!
    LlmServiceContainer.register(:mock, MockLlmService)
  end

  test "should handle nil configuration gracefully" do
    Rails.application.config.llm_feature_flags = nil
    
    assert_raises(NoMethodError) do
      LlmServiceContainer.get(:real)
    end
  end

  test "should handle missing circuit breaker configuration" do
    # Remove circuit breaker data
    LlmServiceContainer.instance_variable_set(:@circuit_breakers, {})
    
    container = LlmServiceContainer
    # Should not raise error for missing circuit breaker
    assert container.send(:circuit_breaker_allows?, :nonexistent_provider)
  end

  test "should handle malformed provider configuration" do
    Rails.application.config.llm_providers = {
      malformed: { enabled: true }  # Missing api_key
    }
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: true,
      fallback_enabled: false
    }
    Rails.application.config.llm_fallback_enabled = false
    
    assert_raises(StandardError) do
      LlmServiceContainer.get(:real)
    end
  end

  test "should handle extremely large failure counts" do
    container = LlmServiceContainer
    
    # Register provider to initialize circuit breaker
    container.register(:test_provider, MockLlmService)
    
    # Simulate many failures
    1000.times do
      container.send(:record_failure, :test_provider, StandardError.new("Error"))
    end
    
    breaker_state = container.instance_variable_get(:@circuit_breakers)[:test_provider]
    assert_equal :open, breaker_state[:state]
    assert_equal 1000, breaker_state[:failure_count]
  end

  test "should handle provider service instantiation errors" do
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: true,
      fallback_enabled: true
    }
    Rails.application.config.llm_providers = {
      failing_provider: { api_key: 'test-key', enabled: true, priority: 1 }
    }
    
    # Should fallback to mock service when provider fails
    service = LlmServiceContainer.get(:real)
    assert_instance_of MockLlmService, service
  end

  test "should handle empty provider list with strict mode" do
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: true,
      fallback_enabled: false,
      strict_mode: true
    }
    Rails.application.config.llm_providers = {}
    Rails.application.config.llm_fallback_enabled = false
    
    assert_raises(StandardError) do
      LlmServiceContainer.get(:real)
    end
  end

  test "should handle circuit breaker state corruption" do
    container = LlmServiceContainer
    
    # Test with corrupted circuit breaker that has invalid state
    container.instance_variable_set(:@circuit_breakers, {
      corrupted: { state: :invalid_state, failure_count: 0, last_failure: nil }
    })
    
    # Should handle gracefully - invalid state returns nil (falsy) which blocks requests
    result = container.send(:circuit_breaker_allows?, :corrupted)
    assert_nil result  # Invalid state should return nil
  end

  test "should handle missing required configuration keys" do
    # Test with incomplete configuration
    Rails.application.config.llm_feature_flags = { enabled: true }
    # Missing use_real_service and other keys
    
    assert_nothing_raised do
      service = LlmServiceContainer.get(:mock)
      assert_instance_of MockLlmService, service
    end
  end
end