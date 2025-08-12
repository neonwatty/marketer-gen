require "test_helper"

class SimpleRetryTest < ActiveSupport::TestCase
  class MockAiService
    include ActiveModel::Model  
    include ActiveModel::Attributes
    include AiRateLimiter
    include AiResponseCache
    include AiRetryStrategies

    attribute :provider_name, :string, default: "test"
    attribute :api_key, :string, default: "test-key"
    attribute :model_name, :string, default: "test-model"
    attribute :timeout_seconds, :integer, default: 30
    attribute :max_retries, :integer, default: 3
    attribute :retry_delay_seconds, :integer, default: 1

    def initialize(attributes = {})
      super(attributes)
      @errors = []
      @last_request = nil
      @last_response = nil
      @circuit_breaker_state = :closed
      @failure_count = 0
      @last_failure_time = nil
      @success_count = 0
    end

    def estimate_token_count(text)
      (text.to_s.length / 4.0).ceil
    end

    def healthy?; true; end
    def validate_configuration; true; end
  end

  test "exponential backoff calculation works" do
    service = MockAiService.new(
      base_retry_delay: 1.0,
      backoff_multiplier: 2.0,
      jitter_factor: 0.1
    )

    delay_0 = service.send(:calculate_exponential_backoff_with_jitter, 0)
    delay_1 = service.send(:calculate_exponential_backoff_with_jitter, 1)

    assert delay_0 >= 1.0, "First delay should be at least 1 second"
    assert delay_1 >= 2.0, "Second delay should be at least 2 seconds"
    assert delay_1 > delay_0, "Second delay should be longer than first"
  end

  test "manual override functionality works" do
    service = MockAiService.new

    service.set_manual_override!("Testing override", expires_in: 1.hour)

    assert service.manual_override_enabled
    assert_equal "Testing override", service.override_reason
    assert service.override_expires_at.present?

    assert_raises(AiRetryStrategies::ManualOverrideError) do
      service.send(:check_manual_override!)
    end

    service.clear_manual_override!

    assert_not service.manual_override_enabled
  end

  test "fallback provider parsing works" do
    service = MockAiService.new(fallback_providers: "openai:gpt-4o,anthropic:claude")
    
    parsed = service.send(:parsed_fallback_providers)
    
    assert_equal 2, parsed.length
    assert_equal :openai, parsed[0][:provider]
    assert_equal "gpt-4o", parsed[0][:model]
  end
end