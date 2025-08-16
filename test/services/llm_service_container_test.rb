# frozen_string_literal: true

require 'test_helper'

class LlmServiceContainerTest < ActiveSupport::TestCase
  setup do
    LlmServiceContainer.clear!
  end

  teardown do
    LlmServiceContainer.clear!
    # Re-register the mock service for other tests
    LlmServiceContainer.register(:mock, MockLlmService)
  end

  test "registers and retrieves services" do
    LlmServiceContainer.register(:test_service, MockLlmService)
    
    assert LlmServiceContainer.registered?(:test_service)
    assert_includes LlmServiceContainer.registered_services, :test_service
    
    service = LlmServiceContainer.get(:test_service)
    assert_instance_of MockLlmService, service
  end

  test "returns singleton instances" do
    LlmServiceContainer.register(:singleton_test, MockLlmService)
    
    service1 = LlmServiceContainer.get(:singleton_test)
    service2 = LlmServiceContainer.get(:singleton_test)
    
    assert_same service1, service2
  end

  test "raises error for unregistered service" do
    assert_raises(ArgumentError) do
      LlmServiceContainer.get(:nonexistent_service)
    end
  end

  test "clears all registrations" do
    LlmServiceContainer.register(:test1, MockLlmService)
    LlmServiceContainer.register(:test2, MockLlmService)
    
    assert_equal 2, LlmServiceContainer.registered_services.length
    
    LlmServiceContainer.clear!
    
    assert_equal 0, LlmServiceContainer.registered_services.length
  end
end