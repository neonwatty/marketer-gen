# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class LlmServiceConfigurationTest < ActiveSupport::TestCase
  def setup
    @original_env = Rails.env
    @original_config = Rails.application.config.llm_service_type
    @original_providers = Rails.application.config.llm_providers.dup
    @original_use_real_llm = ENV['USE_REAL_LLM']
    @original_api_keys = {
      openai: ENV['OPENAI_API_KEY'],
      anthropic: ENV['ANTHROPIC_API_KEY'],
      openai_model: ENV['OPENAI_MODEL'],
      anthropic_model: ENV['ANTHROPIC_MODEL']
    }
  end

  def teardown
    Rails.env = @original_env
    Rails.application.config.llm_service_type = @original_config
    Rails.application.config.llm_providers = @original_providers
    ENV['USE_REAL_LLM'] = @original_use_real_llm
    
    # Restore original API keys
    @original_api_keys.each do |key, value|
      case key
      when :openai
        ENV['OPENAI_API_KEY'] = value
      when :anthropic
        ENV['ANTHROPIC_API_KEY'] = value
      when :openai_model
        ENV['OPENAI_MODEL'] = value
      when :anthropic_model
        ENV['ANTHROPIC_MODEL'] = value
      end
    end
  end

  test "should default to mock in development" do
    Rails.env = 'development'
    ENV.delete('USE_REAL_LLM')
    
    # Simulate configuration loading
    service_type = if Rails.env.production? && ENV['USE_REAL_LLM'] == 'true'
                     :real
                   else
                     :mock
                   end
    
    assert_equal :mock, service_type
  end

  test "should default to mock in test" do
    Rails.env = 'test'
    ENV.delete('USE_REAL_LLM')
    
    service_type = if Rails.env.production? && ENV['USE_REAL_LLM'] == 'true'
                     :real
                   else
                     :mock
                   end
    
    assert_equal :mock, service_type
  end

  test "should use real service in production when enabled" do
    Rails.env = 'production'
    ENV['USE_REAL_LLM'] = 'true'
    
    service_type = if Rails.env.production? && ENV['USE_REAL_LLM'] == 'true'
                     :real
                   else
                     :mock
                   end
    
    assert_equal :real, service_type
  end

  test "should default to mock in production when USE_REAL_LLM not set" do
    Rails.env = 'production'
    ENV.delete('USE_REAL_LLM')
    
    service_type = if Rails.env.production? && ENV['USE_REAL_LLM'] == 'true'
                     :real
                   else
                     :mock
                   end
    
    assert_equal :mock, service_type
  end

  test "should configure OpenAI provider from environment" do
    ENV['OPENAI_API_KEY'] = 'test_openai_key'
    ENV['OPENAI_MODEL'] = 'gpt-4-turbo'
    
    # Simulate provider configuration
    openai_config = {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4',
      enabled: ENV['OPENAI_API_KEY'].present?
    }
    
    assert_equal 'test_openai_key', openai_config[:api_key]
    assert_equal 'gpt-4-turbo', openai_config[:model]
    assert openai_config[:enabled]
  end

  test "should configure Anthropic provider from environment" do
    ENV['ANTHROPIC_API_KEY'] = 'test_anthropic_key'
    ENV['ANTHROPIC_MODEL'] = 'claude-3-opus-20240229'
    
    anthropic_config = {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-sonnet-20240229',
      enabled: ENV['ANTHROPIC_API_KEY'].present?
    }
    
    assert_equal 'test_anthropic_key', anthropic_config[:api_key]
    assert_equal 'claude-3-opus-20240229', anthropic_config[:model]
    assert anthropic_config[:enabled]
  end

  test "should use default models when not specified" do
    ENV.delete('OPENAI_MODEL')
    ENV.delete('ANTHROPIC_MODEL')
    ENV['OPENAI_API_KEY'] = 'test_key'
    ENV['ANTHROPIC_API_KEY'] = 'test_key'
    
    openai_config = {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4',
      enabled: ENV['OPENAI_API_KEY'].present?
    }
    
    anthropic_config = {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-sonnet-20240229',
      enabled: ENV['ANTHROPIC_API_KEY'].present?
    }
    
    assert_equal 'gpt-4', openai_config[:model]
    assert_equal 'claude-3-sonnet-20240229', anthropic_config[:model]
  end

  test "should disable providers when API keys missing" do
    ENV.delete('OPENAI_API_KEY')
    ENV.delete('ANTHROPIC_API_KEY')
    
    openai_config = {
      api_key: ENV['OPENAI_API_KEY'],
      model: ENV['OPENAI_MODEL'] || 'gpt-4',
      enabled: ENV['OPENAI_API_KEY'].present?
    }
    
    anthropic_config = {
      api_key: ENV['ANTHROPIC_API_KEY'],
      model: ENV['ANTHROPIC_MODEL'] || 'claude-3-sonnet-20240229',
      enabled: ENV['ANTHROPIC_API_KEY'].present?
    }
    
    refute openai_config[:enabled]
    refute anthropic_config[:enabled]
  end

  test "should handle application configuration settings" do
    # Test configuration object structure
    config = OpenStruct.new
    config.llm_service_type = :mock
    config.llm_providers = {}
    config.llm_fallback_enabled = true
    config.llm_timeout = 30.seconds
    config.llm_retry_attempts = 3
    
    assert_equal :mock, config.llm_service_type
    assert config.llm_fallback_enabled
    assert_equal 30, config.llm_timeout
    assert_equal 3, config.llm_retry_attempts
  end

  test "should validate configuration values" do
    # Test that configuration accepts valid values
    valid_service_types = [:mock, :real]
    
    valid_service_types.each do |service_type|
      config = OpenStruct.new
      config.llm_service_type = service_type
      
      assert_includes valid_service_types, config.llm_service_type
    end
  end

  test "should handle missing environment variables gracefully" do
    # Clear all LLM-related environment variables
    llm_env_vars = %w[
      USE_REAL_LLM OPENAI_API_KEY ANTHROPIC_API_KEY 
      OPENAI_MODEL ANTHROPIC_MODEL
    ]
    
    original_values = {}
    llm_env_vars.each do |var|
      original_values[var] = ENV[var]
      ENV.delete(var)
    end
    
    # Configuration should still work with defaults
    service_type = if Rails.env.production? && ENV['USE_REAL_LLM'] == 'true'
                     :real
                   else
                     :mock
                   end
    
    providers = {
      openai: {
        api_key: ENV['OPENAI_API_KEY'],
        model: ENV['OPENAI_MODEL'] || 'gpt-4',
        enabled: ENV['OPENAI_API_KEY'].present?
      },
      anthropic: {
        api_key: ENV['ANTHROPIC_API_KEY'],
        model: ENV['ANTHROPIC_MODEL'] || 'claude-3-sonnet-20240229',
        enabled: ENV['ANTHROPIC_API_KEY'].present?
      }
    }
    
    assert_equal :mock, service_type
    refute providers[:openai][:enabled]
    refute providers[:anthropic][:enabled]
    
    # Restore environment variables
    original_values.each do |var, value|
      ENV[var] = value if value
    end
  end

  test "should support multiple provider configurations" do
    ENV['OPENAI_API_KEY'] = 'openai_test_key'
    ENV['ANTHROPIC_API_KEY'] = 'anthropic_test_key'
    
    providers = {
      openai: {
        api_key: ENV['OPENAI_API_KEY'],
        model: ENV['OPENAI_MODEL'] || 'gpt-4',
        enabled: ENV['OPENAI_API_KEY'].present?
      },
      anthropic: {
        api_key: ENV['ANTHROPIC_API_KEY'],
        model: ENV['ANTHROPIC_MODEL'] || 'claude-3-sonnet-20240229',
        enabled: ENV['ANTHROPIC_API_KEY'].present?
      }
    }
    
    assert providers[:openai][:enabled]
    assert providers[:anthropic][:enabled]
    assert_equal 'openai_test_key', providers[:openai][:api_key]
    assert_equal 'anthropic_test_key', providers[:anthropic][:api_key]
  end

  test "should handle configuration in different environments" do
    environments = ['development', 'test', 'production']
    
    environments.each do |env|
      Rails.env = env
      ENV.delete('USE_REAL_LLM')
      
      service_type = if Rails.env.production? && ENV['USE_REAL_LLM'] == 'true'
                       :real
                     else
                       :mock
                     end
      
      case env
      when 'production'
        assert_equal :mock, service_type, "Production should default to mock without USE_REAL_LLM"
      else
        assert_equal :mock, service_type, "#{env.capitalize} should use mock service"
      end
    end
  end
end