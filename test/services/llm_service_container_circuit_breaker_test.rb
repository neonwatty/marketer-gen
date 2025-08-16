# frozen_string_literal: true

require 'test_helper'

class LlmServiceContainerCircuitBreakerTest < ActiveSupport::TestCase
  def setup
    LlmServiceContainer.clear!
    LlmServiceContainer.register(:mock, MockLlmService)
    
    # Set test configuration
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: true,
      fallback_enabled: true
    }
    Rails.application.config.llm_circuit_breaker_threshold = 2
    Rails.application.config.llm_circuit_breaker_timeout = 1.second
    Rails.application.config.llm_providers = {
      test_provider: {
        api_key: 'test-key',
        enabled: true,
        priority: 1
      }
    }
  end

  test "should open circuit breaker after threshold failures" do
    container = LlmServiceContainer
    
    # Initialize circuit breaker for test_provider
    container.register(:test_provider, MockLlmService)
    
    # Simulate failures to reach threshold
    2.times do
      container.send(:record_failure, :test_provider, StandardError.new("API error"))
    end
    
    breaker_state = container.instance_variable_get(:@circuit_breakers)[:test_provider]
    assert_equal :open, breaker_state[:state]
    assert_equal 2, breaker_state[:failure_count]
    assert_not_nil breaker_state[:last_failure]
  end

  test "should allow requests after circuit breaker timeout" do
    container = LlmServiceContainer
    
    # Initialize circuit breaker for test_provider
    container.register(:test_provider, MockLlmService)
    
    # Open circuit breaker
    container.instance_variable_get(:@circuit_breakers)[:test_provider] = {
      failure_count: 3,
      last_failure: 2.seconds.ago,
      state: :open
    }
    
    # Should transition to half-open and allow request
    assert container.send(:circuit_breaker_allows?, :test_provider)
    
    # Verify state transition
    breaker_state = container.instance_variable_get(:@circuit_breakers)[:test_provider]
    assert_equal :half_open, breaker_state[:state]
  end

  test "should prevent requests when circuit breaker is open" do
    container = LlmServiceContainer
    
    # Initialize circuit breaker for test_provider
    container.register(:test_provider, MockLlmService)
    
    # Set circuit breaker to open state with recent failure
    container.instance_variable_get(:@circuit_breakers)[:test_provider] = {
      failure_count: 3,
      last_failure: Time.current,
      state: :open
    }
    
    # Should block requests
    refute container.send(:circuit_breaker_allows?, :test_provider)
  end

  test "should reset circuit breaker on successful request" do
    container = LlmServiceContainer
    
    # Initialize circuit breaker for test_provider
    container.register(:test_provider, MockLlmService)
    
    # Set initial failure state
    container.instance_variable_get(:@circuit_breakers)[:test_provider] = {
      failure_count: 2,
      last_failure: Time.current,
      state: :half_open
    }
    
    # Record success
    container.send(:record_success, :test_provider)
    
    # Verify reset
    breaker_state = container.instance_variable_get(:@circuit_breakers)[:test_provider]
    assert_equal :closed, breaker_state[:state]
    assert_equal 0, breaker_state[:failure_count]
  end
end