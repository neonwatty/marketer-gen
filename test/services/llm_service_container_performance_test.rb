# frozen_string_literal: true

require 'test_helper'

class LlmServiceContainerPerformanceTest < ActiveSupport::TestCase
  def setup
    LlmServiceContainer.clear!
    LlmServiceContainer.register(:mock, MockLlmService)
    
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: false,
      fallback_enabled: true
    }
  end

  test "should handle concurrent service requests" do
    threads = []
    results = []
    
    # Create multiple concurrent requests
    10.times do
      threads << Thread.new do
        service = LlmServiceContainer.get(:mock)
        results << service.health_check
      end
    end
    
    # Wait for all threads to complete
    threads.each(&:join)
    
    # Verify all requests succeeded
    assert_equal 10, results.length
    results.each do |result|
      assert_equal 'healthy', result[:status]
    end
  end

  test "should maintain singleton behavior under load" do
    services = []
    
    # Get service instance multiple times rapidly
    100.times do
      services << LlmServiceContainer.get(:mock)
    end
    
    # All should be the same instance (singleton)
    first_service = services.first
    services.each do |service|
      assert_same first_service, service
    end
  end

  test "should handle rapid configuration changes" do
    # Rapidly switch configurations
    10.times do |i|
      Rails.application.config.llm_feature_flags[:use_real_service] = i.even?
      service = LlmServiceContainer.get(:mock)
      assert_instance_of MockLlmService, service
    end
  end
end