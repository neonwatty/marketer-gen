# frozen_string_literal: true

require 'test_helper'

class LlmServiceHelperIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    LlmServiceContainer.clear!
    LlmServiceContainer.register(:mock, MockLlmService)
  end

  test "should handle LLM service errors gracefully in controller context" do
    # Test with LLM disabled - should return mock service
    Rails.application.config.llm_feature_flags = { enabled: false, fallback_enabled: true }
    
    # Test through an existing controller that uses the helper
    # First check if we can access the home controller
    get root_path
    assert_response :success
    
    # Verify service fallback behavior directly
    service = LlmServiceContainer.get(:real)
    assert_instance_of MockLlmService, service
  end

  test "should fallback to mock service when no providers available" do
    # Set up failing scenario
    Rails.application.config.llm_feature_flags = {
      enabled: true,
      use_real_service: true,
      fallback_enabled: true
    }
    Rails.application.config.llm_providers = {}
    Rails.application.config.llm_fallback_enabled = true
    
    # Should fallback to mock service
    service = LlmServiceContainer.get(:real)
    assert_instance_of MockLlmService, service
    
    # Verify fallback behavior works in the helper as well
    helper_class = Class.new do
      include LlmServiceHelper
    end
    
    helper_instance = helper_class.new
    service_from_helper = helper_instance.send(:llm_service)
    assert_instance_of MockLlmService, service_from_helper
  end
end