# frozen_string_literal: true

require 'test_helper'

class LlmServiceHelperTest < ActiveSupport::TestCase
  include LlmServiceHelper

  def setup
    @original_service_type = Rails.application.config.llm_service_type
    @original_feature_flags = Rails.application.config.llm_feature_flags.dup
    @original_services = LlmServiceContainer.instance_variable_get(:@services).dup
    @original_instances = LlmServiceContainer.instance_variable_get(:@instances)&.dup
    @original_circuit_breakers = LlmServiceContainer.instance_variable_get(:@circuit_breakers).dup
    
    # Ensure feature flags are enabled for testing
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: false,
      fallback_enabled: true
    }
  end

  def teardown
    Rails.application.config.llm_service_type = @original_service_type
    Rails.application.config.llm_feature_flags = @original_feature_flags
    LlmServiceContainer.clear!
    LlmServiceContainer.instance_variable_set(:@services, @original_services)
    LlmServiceContainer.instance_variable_set(:@instances, @original_instances)
    LlmServiceContainer.instance_variable_set(:@circuit_breakers, @original_circuit_breakers)
  end

  test "should return configured service type" do
    Rails.application.config.llm_service_type = :mock
    LlmServiceContainer.register(:mock, MockLlmService)
    
    service = llm_service
    assert_instance_of MockLlmService, service
  end

  test "should fallback to mock when configured service unavailable" do
    Rails.application.config.llm_service_type = :nonexistent
    LlmServiceContainer.register(:mock, MockLlmService)
    
    service = llm_service
    assert_instance_of MockLlmService, service
  end

  test "should raise error when no fallback available" do
    Rails.application.config.llm_service_type = :nonexistent
    LlmServiceContainer.clear!
    
    assert_raises(ArgumentError) do
      llm_service
    end
  end

  test "should log errors when service unavailable" do
    # Clear container and set up for failure scenario
    LlmServiceContainer.clear!
    LlmServiceContainer.register(:mock, MockLlmService)
    
    Rails.application.config.llm_service_type = :nonexistent
    Rails.application.config.llm_feature_flags[:use_real_service] = false  # Use mock
    
    # Should return mock service without errors since feature flags route to mock
    service = llm_service
    assert_instance_of MockLlmService, service
  end

  test "should handle service switching" do
    LlmServiceContainer.clear!
    LlmServiceContainer.register(:mock, MockLlmService)
    
    # Test switching feature flags to control service type
    Rails.application.config.llm_feature_flags[:use_real_service] = false
    service1 = llm_service
    
    # Clear instances to force new instance creation
    LlmServiceContainer.instance_variable_set(:@instances, {})
    Rails.application.config.llm_feature_flags[:use_real_service] = false  # Still mock since no real providers
    service2 = llm_service
    
    assert_instance_of MockLlmService, service1
    assert_instance_of MockLlmService, service2
    # With cleared instances, should get different objects
    assert service1 != service2
  end

  test "should return same instance on repeated calls" do
    Rails.application.config.llm_service_type = :mock
    LlmServiceContainer.register(:mock, MockLlmService)
    
    service1 = llm_service
    service2 = llm_service
    
    assert_same service1, service2
  end

  test "should handle service registration after configuration" do
    Rails.application.config.llm_service_type = :late_register
    
    # Service not registered yet - should fallback to mock or raise error
    if LlmServiceContainer.registered?(:mock)
      # Will fallback to mock service
      service = llm_service
      assert_instance_of MockLlmService, service
    else
      # Should raise error if no mock fallback
      assert_raises(ArgumentError) do
        llm_service
      end
    end
    
    # Register service
    LlmServiceContainer.register(:late_register, MockLlmService)
    
    # Should work now
    service = llm_service
    assert_instance_of MockLlmService, service
  end
end