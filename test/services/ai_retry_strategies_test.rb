require "test_helper"

class AiRetryStrategiesTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  class TestAiService < AiServiceBase
    include AiRetryStrategies
    
    def initialize(attributes = {})
      super(attributes.merge(
        provider_name: "test",
        model_name: "test-model",
        api_key: "test-key"
      ))
    end
    
    def generate_content(prompt, options = {})
      # Override to avoid NotImplementedError
      "test response"
    end
  end

  setup do
    @service = TestAiService.new
    # Clear any existing alert history
    AiAlertingService.instance.cleanup_alert_history(0)
  end

  test "exponential backoff with jitter calculation" do
    @service.base_retry_delay = 1.0
    @service.backoff_multiplier = 2.0
    @service.max_retry_delay = 60.0
    @service.jitter_factor = 0.25

    # First attempt (attempt 0)
    delay_0 = @service.send(:calculate_exponential_backoff_with_jitter, 0)
    assert delay_0 >= 1.0 && delay_0 <= 1.25, "First delay should be between 1.0 and 1.25 seconds"

    # Second attempt (attempt 1)  
    delay_1 = @service.send(:calculate_exponential_backoff_with_jitter, 1)
    assert delay_1 >= 2.0 && delay_1 <= 2.5, "Second delay should be between 2.0 and 2.5 seconds"

    # Third attempt (attempt 2)
    delay_2 = @service.send(:calculate_exponential_backoff_with_jitter, 2)
    assert delay_2 >= 4.0 && delay_2 <= 5.0, "Third delay should be between 4.0 and 5.0 seconds"
  end

  test "fallback provider parsing" do
    @service.fallback_providers = "openai:gpt-4o-mini,anthropic:claude-3-haiku"
    
    parsed = @service.send(:parsed_fallback_providers)
    
    assert_equal 2, parsed.length
    assert_equal :openai, parsed[0][:provider]
    assert_equal "gpt-4o-mini", parsed[0][:model]
    assert_equal :anthropic, parsed[1][:provider]
    assert_equal "claude-3-haiku", parsed[1][:model]
  end

  test "manual override functionality" do
    reason = "Testing manual override"
    
    @service.set_manual_override!(reason, expires_in: 1.hour)
    
    assert @service.manual_override_enabled
    assert_equal reason, @service.override_reason
    assert @service.override_expires_at > Time.current
    
    # Should raise error when trying to make requests
    assert_raises(AiRetryStrategies::ManualOverrideError) do
      @service.send(:check_manual_override!)
    end
    
    @service.clear_manual_override!
    
    assert_not @service.manual_override_enabled
    assert_nil @service.override_reason
    assert_nil @service.override_expires_at
  end

  test "manual override expiration" do
    @service.set_manual_override!("Test", expires_in: 0.1.seconds)
    
    assert @service.manual_override_enabled
    
    sleep(0.2)
    
    # Should automatically clear expired override
    @service.send(:check_manual_override!)
    
    assert_not @service.manual_override_enabled
  end

  test "degraded mode providers parsing" do
    @service.degraded_mode_providers = "openai:gpt-4o-mini,gemini:gemini-1.5-flash"
    
    parsed = @service.send(:parsed_degraded_mode_providers)
    
    assert_equal 2, parsed.length
    assert_equal :openai, parsed[0][:provider]
    assert_equal "gpt-4o-mini", parsed[0][:model]
    assert_equal :gemini, parsed[1][:provider]
    assert_equal "gemini-1.5-flash", parsed[1][:model]
  end

  test "default model mapping" do
    assert_equal "gpt-4o-mini", @service.send(:get_default_model_for_provider, "openai")
    assert_equal "claude-3-5-haiku-20241022", @service.send(:get_default_model_for_provider, "anthropic")
    assert_equal "gemini-1.5-flash", @service.send(:get_default_model_for_provider, "gemini")
    assert_nil @service.send(:get_default_model_for_provider, "unknown")
  end

  test "adaptive delay calculation with different error types" do
    recent_times = [1.0, 2.0, 1.5] # Average: 1.5 seconds
    
    # Rate limit error should have longer delay
    rate_limit_delay = @service.send(:calculate_adaptive_delay, 0, :rate_limit, recent_times)
    general_delay = @service.send(:calculate_adaptive_delay, 0, :general, recent_times)
    
    # Rate limit delay should be longer (base_delay * 3 vs base_delay)
    assert rate_limit_delay > general_delay
  end

  test "request metrics recording" do
    @service.send(:record_request_metric, :success, {
      provider: "test",
      model: "test-model",
      attempt: 1,
      duration: 2.5,
      degraded_mode: false
    })
    
    metric_key = "ai_metrics:test:#{Date.current}"
    metrics = Rails.cache.read(metric_key)
    
    assert_not_nil metrics
    assert_equal 1, metrics[:successes]
    assert_equal 2.5, metrics[:total_duration]
  end

  test "recent response times calculation" do
    # Setup some historical metrics
    yesterday_key = "ai_metrics:test:#{Date.current - 1}"
    today_key = "ai_metrics:test:#{Date.current}"
    
    Rails.cache.write(yesterday_key, { successes: 10, total_duration: 25.0 })
    Rails.cache.write(today_key, { successes: 5, total_duration: 10.0 })
    
    response_times = @service.send(:get_recent_response_times)
    
    assert response_times.include?(2.5) # yesterday: 25.0 / 10
    assert response_times.include?(2.0) # today: 10.0 / 5
  end

  test "retry strategy configurations" do
    # Test different retry strategies
    strategies = ["exponential_backoff_with_jitter", "linear_backoff", "fibonacci_backoff", "adaptive_backoff"]
    
    strategies.each do |strategy|
      @service.retry_strategy = strategy
      assert_equal strategy, @service.retry_strategy
    end
  end
end