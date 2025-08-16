# frozen_string_literal: true

require 'test_helper'

class LlmServiceContainerEdgeCasesTest < ActiveSupport::TestCase
  def setup
    @original_services = LlmServiceContainer.instance_variable_get(:@services).dup
    @original_instances = LlmServiceContainer.instance_variable_get(:@instances)&.dup
    LlmServiceContainer.clear!
  end

  def teardown
    LlmServiceContainer.clear!
    # Restore original services
    LlmServiceContainer.instance_variable_set(:@services, @original_services)
    LlmServiceContainer.instance_variable_set(:@instances, @original_instances)
  end

  test "should handle service registration collision" do
    LlmServiceContainer.register(:test_service, MockLlmService)
    LlmServiceContainer.register(:test_service, String)
    
    # Should overwrite previous registration
    assert_equal String, LlmServiceContainer.instance_variable_get(:@services)[:test_service]
  end

  test "should maintain singleton instances" do
    LlmServiceContainer.register(:singleton_test, MockLlmService)
    
    instance1 = LlmServiceContainer.get(:singleton_test)
    instance2 = LlmServiceContainer.get(:singleton_test)
    
    assert_same instance1, instance2
  end

  test "should handle service class that fails to initialize" do
    broken_service = Class.new do
      def initialize
        raise StandardError, "Initialization failed"
      end
    end
    
    LlmServiceContainer.register(:broken, broken_service)
    
    assert_raises(StandardError) do
      LlmServiceContainer.get(:broken)
    end
  end

  test "should clear instances when clearing registrations" do
    LlmServiceContainer.register(:test, MockLlmService)
    LlmServiceContainer.get(:test) # Create instance
    
    LlmServiceContainer.clear!
    
    assert_empty LlmServiceContainer.registered_services
    refute LlmServiceContainer.registered?(:test)
  end

  test "should handle multiple registrations and retrievals" do
    LlmServiceContainer.register(:service1, MockLlmService)
    LlmServiceContainer.register(:service2, MockLlmService)
    
    assert LlmServiceContainer.registered?(:service1)
    assert LlmServiceContainer.registered?(:service2)
    
    service1 = LlmServiceContainer.get(:service1)
    service2 = LlmServiceContainer.get(:service2)
    
    assert_instance_of MockLlmService, service1
    assert_instance_of MockLlmService, service2
    refute_same service1, service2
  end

  test "should list all registered services" do
    LlmServiceContainer.register(:service_a, MockLlmService)
    LlmServiceContainer.register(:service_b, String)
    
    services = LlmServiceContainer.registered_services
    assert_includes services, :service_a
    assert_includes services, :service_b
    assert_equal 2, services.length
  end

  test "should handle symbol and string service names consistently" do
    LlmServiceContainer.register('string_service', MockLlmService)
    LlmServiceContainer.register(:symbol_service, MockLlmService)
    
    # Should handle both types
    assert LlmServiceContainer.registered?('string_service')
    assert LlmServiceContainer.registered?(:symbol_service)
  end

  test "should raise descriptive error for unregistered service" do
    error = assert_raises(ArgumentError) do
      LlmServiceContainer.get(:nonexistent)
    end
    
    assert_match(/Service nonexistent not registered/, error.message)
  end

  test "should handle nil service class registration" do
    assert_raises(ArgumentError) do
      LlmServiceContainer.register(:nil_service, nil)
      LlmServiceContainer.get(:nil_service)
    end
  end
end