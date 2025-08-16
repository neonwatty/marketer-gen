# frozen_string_literal: true

require 'test_helper'

class LlmServiceHelperTest < ActiveSupport::TestCase
  include LlmServiceHelper

  def setup
    @original_service_type = Rails.application.config.llm_service_type
    @original_services = LlmServiceContainer.instance_variable_get(:@services).dup
    @original_instances = LlmServiceContainer.instance_variable_get(:@instances)&.dup
  end

  def teardown
    Rails.application.config.llm_service_type = @original_service_type
    LlmServiceContainer.clear!
    LlmServiceContainer.instance_variable_set(:@services, @original_services)
    LlmServiceContainer.instance_variable_set(:@instances, @original_instances)
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
    Rails.application.config.llm_service_type = :nonexistent
    LlmServiceContainer.register(:mock, MockLlmService)
    
    Rails.logger.expects(:error).with(regexp_matches(/LLM Service Error/))
    Rails.logger.expects(:warn).with("Falling back to mock LLM service")
    
    llm_service
  end

  test "should handle service switching" do
    # Register multiple services
    LlmServiceContainer.register(:mock, MockLlmService)
    LlmServiceContainer.register(:alternative, MockLlmService)
    
    # Test switching between services
    Rails.application.config.llm_service_type = :mock
    service1 = llm_service
    
    Rails.application.config.llm_service_type = :alternative
    service2 = llm_service
    
    assert_instance_of MockLlmService, service1
    assert_instance_of MockLlmService, service2
    # Should be different instances due to singleton per service type
    refute_same service1, service2
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