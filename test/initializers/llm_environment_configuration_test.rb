# frozen_string_literal: true

require 'test_helper'

class LlmEnvironmentConfigurationTest < ActiveSupport::TestCase
  def setup
    @original_env = ENV.to_h
  end

  def teardown
    ENV.clear
    @original_env.each { |k, v| ENV[k] = v }
  end

  test "should configure all provider settings from environment" do
    set_test_environment({
      'OPENAI_API_KEY' => 'sk-test-openai',
      'OPENAI_MODEL' => 'gpt-4-turbo',
      'OPENAI_PRIORITY' => '1',
      'OPENAI_MAX_TOKENS' => '8000',
      'OPENAI_TEMPERATURE' => '0.3',
      'ANTHROPIC_API_KEY' => 'sk-ant-test',
      'ANTHROPIC_PRIORITY' => '2',
      'GOOGLE_AI_API_KEY' => 'google-test',
      'GOOGLE_AI_ENABLED' => 'true',
      'GOOGLE_AI_PRIORITY' => '3'
    })
    
    # Reload configuration
    load Rails.root.join('config', 'initializers', 'llm_service.rb')
    
    providers = Rails.application.config.llm_providers
    
    # Verify OpenAI configuration
    assert_equal 'sk-test-openai', providers[:openai][:api_key]
    assert_equal 'gpt-4-turbo', providers[:openai][:model]
    assert_equal 1, providers[:openai][:priority]
    assert_equal 8000, providers[:openai][:max_tokens]
    assert_equal 0.3, providers[:openai][:temperature]
    assert providers[:openai][:enabled]
    
    # Verify Anthropic configuration
    assert_equal 'sk-ant-test', providers[:anthropic][:api_key]
    assert_equal 2, providers[:anthropic][:priority]
    assert providers[:anthropic][:enabled]
    
    # Verify Google AI configuration
    assert_equal 'google-test', providers[:google][:api_key]
    assert_equal 3, providers[:google][:priority]
    assert providers[:google][:enabled]
  end

  test "should handle feature flag combinations" do
    test_cases = [
      {
        env: { 'LLM_ENABLED' => 'false' },
        expected: { enabled: false, use_real_service: false }
      },
      {
        env: { 'LLM_ENABLED' => 'true', 'USE_REAL_LLM' => 'false' },
        expected: { enabled: true, use_real_service: false }
      },
      {
        env: { 'LLM_ENABLED' => 'true', 'USE_REAL_LLM' => 'true' },
        expected: { enabled: true, use_real_service: true }
      }
    ]
    
    test_cases.each do |test_case|
      set_test_environment(test_case[:env])
      load Rails.root.join('config', 'initializers', 'llm_service.rb')
      
      flags = Rails.application.config.llm_feature_flags
      assert_equal test_case[:expected][:enabled], flags[:enabled]
      assert_equal test_case[:expected][:use_real_service], flags[:use_real_service]
    end
  end

  test "should configure resilience settings from environment" do
    set_test_environment({
      'LLM_TIMEOUT' => '60',
      'LLM_RETRY_ATTEMPTS' => '5',
      'LLM_RETRY_DELAY' => '2',
      'LLM_CIRCUIT_BREAKER_THRESHOLD' => '3',
      'LLM_CIRCUIT_BREAKER_TIMEOUT' => '120'
    })
    
    load Rails.root.join('config', 'initializers', 'llm_service.rb')
    config = Rails.application.config
    
    assert_equal 60.seconds, config.llm_timeout
    assert_equal 5, config.llm_retry_attempts
    assert_equal 2.seconds, config.llm_retry_delay
    assert_equal 3, config.llm_circuit_breaker_threshold
    assert_equal 120.seconds, config.llm_circuit_breaker_timeout
  end

  private

  def set_test_environment(vars)
    # Clear LLM-related variables
    ENV.keys.select { |k| k.start_with?('LLM_', 'OPENAI_', 'ANTHROPIC_', 'GOOGLE_AI_', 'USE_REAL_LLM') }.each do |key|
      ENV.delete(key)
    end
    
    # Set test variables
    vars.each { |k, v| ENV[k] = v }
  end
end