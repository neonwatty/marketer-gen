require "test_helper"

class AiServiceBaseTest < ActiveSupport::TestCase
  # Test implementation class for testing abstract base
  class TestAiService < AiServiceBase
    def generate_content(prompt, options = {})
      "Test generated content for: #{prompt}"
    end

    def generate_campaign_plan(campaign_data, options = {})
      {"plan" => "Test campaign plan for #{campaign_data[:name]}"}
    end

    def analyze_brand_assets(assets, options = {})
      {"analysis" => "Test analysis of #{assets.count} assets"}
    end

    def generate_content_for_channel(channel, brand_context, options = {})
      "Test #{channel} content for: #{brand_context}"
    end

    def test_connection
      true
    end
    
    # Override ActiveModel's model_name to avoid conflicts
    def self.model_name
      ActiveModel::Name.new(self, nil, "TestAiService")
    end
  end

  setup do
    @service = TestAiService.new(
      provider_name: "test_provider",
      api_key: "test_key",
      api_base_url: "https://api.test.com",
      model_name: "test-model",
      timeout_seconds: 30,
      max_retries: 3,
      retry_delay_seconds: 1
    )
  end

  # Initialization Tests
  test "should initialize with valid attributes" do
    assert_equal "test_provider", @service.provider_name
    assert_equal "test_key", @service.api_key
    assert_equal "https://api.test.com", @service.api_base_url
    assert_equal "test-model", @service.attributes["model_name"]
    assert_equal 30, @service.timeout_seconds
    assert_equal 3, @service.max_retries
    assert_equal 1, @service.retry_delay_seconds
  end

  test "should set default values for optional attributes" do
    service = TestAiService.new(
      provider_name: "test",
      api_key: "key",
      model_name: "model"
    )
    
    assert_equal 30, service.timeout_seconds
    assert_equal 3, service.max_retries
    assert_equal 1, service.retry_delay_seconds
    assert_equal 5, service.circuit_breaker_failure_threshold
    assert_equal 60, service.circuit_breaker_recovery_timeout
    assert_equal 3, service.circuit_breaker_success_threshold
  end

  test "should initialize circuit breaker in closed state" do
    assert_equal :closed, @service.circuit_breaker_state
  end

  # Configuration Validation Tests
  test "should validate required configuration" do
    assert @service.validate_configuration

    service = TestAiService.new
    assert_raises(AiServiceBase::InvalidRequestError) { service.validate_configuration }
  end

  test "should validate provider_name presence" do
    @service.provider_name = nil
    assert_raises(AiServiceBase::InvalidRequestError) { @service.validate_configuration }
  end

  test "should validate api_key presence" do
    @service.api_key = nil
    assert_raises(AiServiceBase::InvalidRequestError) { @service.validate_configuration }
  end

  test "should validate model_name presence" do
    service = TestAiService.new(
      provider_name: "test",
      api_key: "key"
    )
    # Don't set model_name at all, so it should be nil/blank
    assert_raises(AiServiceBase::InvalidRequestError) { service.validate_configuration }
  end

  # Health Check Tests
  test "should pass health check with valid configuration" do
    assert @service.healthy?
  end

  test "should fail health check with invalid configuration" do
    @service.api_key = nil
    assert_not @service.healthy?
    assert_includes @service.errors.first, "API key is required"
  end

  # Provider Capability Tests
  test "should have default capability settings" do
    assert_not @service.supports_function_calling?
    assert_not @service.supports_image_analysis?
    assert_not @service.supports_streaming?
    assert_equal 4096, @service.max_context_tokens
  end

  # Circuit Breaker Tests
  test "should start with closed circuit breaker" do
    assert_equal :closed, @service.circuit_breaker_state
  end

  test "should open circuit breaker after failure threshold" do
    failure_threshold = @service.circuit_breaker_failure_threshold
    
    # Create a service that will always fail
    failing_service = Class.new(AiServiceBase) do
      def generate_content(prompt, options = {})
        raise StandardError, "Test failure"
      end
      
      def test_connection
        true
      end
    end.new(
      provider_name: "failing",
      api_key: "key", 
      model_name: "model",
      circuit_breaker_failure_threshold: 2  # Lower threshold for testing
    )
    
    # Try to make requests that fail
    2.times do
      begin
        failing_service.send(:make_request_with_retries, -> { failing_service.generate_content("test") })
      rescue StandardError
        # Expected to fail
      end
    end
    
    # Circuit breaker should now be open
    assert_equal :open, failing_service.circuit_breaker_state
  end

  test "should raise CircuitBreakerOpenError when circuit is open" do
    # Manually set circuit breaker to open state
    @service.instance_variable_set(:@circuit_breaker_state, :open)
    @service.instance_variable_set(:@last_failure_time, Time.current.to_i)
    
    assert_raises(AiServiceBase::CircuitBreakerOpenError) do
      @service.send(:make_request_with_retries, -> { "test" })
    end
  end

  test "should move to half-open state after recovery timeout" do
    # Set circuit breaker to open with old failure time
    @service.instance_variable_set(:@circuit_breaker_state, :open)
    @service.instance_variable_set(:@last_failure_time, Time.current.to_i - 120) # 2 minutes ago
    
    # Should move to half-open state
    @service.send(:check_circuit_breaker!)
    assert_equal :half_open, @service.circuit_breaker_state
  end

  test "should close circuit breaker after successful requests in half-open" do
    # Set circuit breaker to half-open
    @service.instance_variable_set(:@circuit_breaker_state, :half_open)
    @service.instance_variable_set(:@success_count, 0)
    
    # Make successful requests
    success_threshold = @service.circuit_breaker_success_threshold
    success_threshold.times do
      @service.send(:make_request_with_retries, -> { "success" })
    end
    
    # Should be closed now
    assert_equal :closed, @service.circuit_breaker_state
  end

  # Request Handling Tests
  test "should handle successful requests" do
    result = @service.send(:make_request_with_retries, -> { "success" })
    assert_equal "success", result
    assert @service.last_request.is_a?(Hash)
    assert @service.last_response.is_a?(Hash)
    assert @service.last_response[:success]
  end

  test "should retry on transient errors" do
    call_count = 0
    failing_proc = -> do
      call_count += 1
      if call_count < 3
        raise AiServiceBase::RateLimitError, "Rate limited"
      else
        "success after retries"
      end
    end
    
    result = @service.send(:make_request_with_retries, failing_proc)
    assert_equal "success after retries", result
    assert_equal 3, call_count
  end

  test "should not retry on non-retryable errors" do
    call_count = 0
    failing_proc = -> do
      call_count += 1
      raise AiServiceBase::AuthenticationError, "Invalid API key"
    end
    
    assert_raises(AiServiceBase::AuthenticationError) do
      @service.send(:make_request_with_retries, failing_proc)
    end
    assert_equal 1, call_count  # Should not retry
  end

  test "should respect max_retries limit" do
    call_count = 0
    failing_proc = -> do
      call_count += 1
      raise AiServiceBase::RateLimitError, "Always rate limited"
    end
    
    assert_raises(AiServiceBase::RateLimitError) do
      @service.send(:make_request_with_retries, failing_proc)
    end
    assert_equal @service.max_retries, call_count
  end

  # Backoff Calculation Tests
  test "should calculate exponential backoff delay" do
    base_delay = 1
    
    delay_0 = @service.send(:calculate_backoff_delay, 0, base_delay)
    delay_1 = @service.send(:calculate_backoff_delay, 1, base_delay)
    delay_2 = @service.send(:calculate_backoff_delay, 2, base_delay)
    
    # Each delay should be roughly double the previous (plus randomization)
    assert delay_0 >= 1.0
    assert delay_0 <= 2.0
    assert delay_1 >= 2.0
    assert delay_1 <= 3.0
    assert delay_2 >= 4.0
    assert delay_2 <= 5.0
  end

  # Logging Tests
  test "should log request start" do
    log_data = @service.send(:log_request_start, 0)
    
    assert log_data.is_a?(Hash)
    assert log_data[:timestamp]
    assert_equal "test_provider", log_data[:provider]
    assert_equal "test-model", log_data[:model]
    assert_equal 1, log_data[:attempt]
  end

  test "should log successful requests" do
    @service.instance_variable_set(:@last_request, {timestamp: Time.current})
    log_data = @service.send(:log_request_success, "test response")
    
    assert log_data.is_a?(Hash)
    assert log_data[:success]
    assert log_data[:duration]
    assert log_data[:response_size]
  end

  test "should log failed requests" do
    @service.instance_variable_set(:@last_request, {timestamp: Time.current})
    error = StandardError.new("Test error")
    log_data = @service.send(:log_request_error, error)
    
    assert log_data.is_a?(Hash)
    assert_not log_data[:success]
    assert_equal "StandardError", log_data[:error_class]
    assert_equal "Test error", log_data[:error_message]
  end

  # Content Processing Tests
  test "should sanitize prompts" do
    messy_prompt = "Test\r\n\r\nprompt\n\n\n\nwith\nexcessive\n\n\nlines"
    sanitized = @service.send(:sanitize_prompt, messy_prompt)
    
    assert_not_includes sanitized, "\r"
    assert_not_includes sanitized, "\n\n\n"
    assert_equal "Test\n\nprompt\n\nwith\nexcessive\n\nlines", sanitized
  end

  test "should handle blank prompts" do
    assert_equal "", @service.send(:sanitize_prompt, nil)
    assert_equal "", @service.send(:sanitize_prompt, "")
    assert_equal "", @service.send(:sanitize_prompt, "   ")
  end

  test "should truncate overly long prompts" do
    # Create a very long prompt
    long_prompt = "a" * 10000
    sanitized = @service.send(:sanitize_prompt, long_prompt)
    
    # Should be truncated
    assert sanitized.length < long_prompt.length
    assert_includes sanitized, "[Content truncated due to length limits]"
  end

  test "should extract JSON from responses" do
    # Test with markdown code block
    response_with_markdown = "Here's the result:\n```json\n{\"test\": \"value\"}\n```"
    result = @service.send(:extract_json_from_response, response_with_markdown)
    assert_equal({"test" => "value"}, result)
    
    # Test with raw JSON
    response_with_json = "Some text {\"key\": \"value\"} more text"
    result = @service.send(:extract_json_from_response, response_with_json)
    assert_equal({"key" => "value"}, result)
    
    # Test with no JSON
    response_no_json = "No JSON here"
    result = @service.send(:extract_json_from_response, response_no_json)
    assert_nil result
    
    # Test with invalid JSON
    response_invalid = "```json\n{invalid: json}\n```"
    result = @service.send(:extract_json_from_response, response_invalid)
    assert_nil result
  end

  # Token Estimation Tests
  test "should estimate token count" do
    text = "This is a test sentence with multiple words."
    estimated_tokens = @service.send(:estimate_token_count, text)
    
    # Rough estimation should be reasonable (text length / 4)
    expected_tokens = (text.length / 4.0).ceil
    assert_equal expected_tokens, estimated_tokens
  end

  test "should handle empty text for token estimation" do
    assert_equal 0, @service.send(:estimate_token_count, "")
    assert_equal 0, @service.send(:estimate_token_count, nil)
  end

  # Error Class Tests
  test "should define proper error hierarchy" do
    assert AiServiceBase::AIServiceError < StandardError
    assert AiServiceBase::ProviderError < AiServiceBase::AIServiceError
    assert AiServiceBase::RateLimitError < AiServiceBase::AIServiceError
    assert AiServiceBase::AuthenticationError < AiServiceBase::AIServiceError
    assert AiServiceBase::InvalidRequestError < AiServiceBase::AIServiceError
    assert AiServiceBase::ContextTooLongError < AiServiceBase::AIServiceError
    assert AiServiceBase::InsufficientCreditsError < AiServiceBase::AIServiceError
    assert AiServiceBase::ProviderUnavailableError < AiServiceBase::AIServiceError
    assert AiServiceBase::CircuitBreakerOpenError < AiServiceBase::AIServiceError
  end

  # Interface Method Tests
  test "should require subclasses to implement interface methods" do
    abstract_service = AiServiceBase.new(
      provider_name: "test",
      api_key: "key",
      model_name: "model"
    )
    
    assert_raises(NotImplementedError) { abstract_service.generate_content("test") }
    assert_raises(NotImplementedError) { abstract_service.generate_campaign_plan({}) }
    assert_raises(NotImplementedError) { abstract_service.analyze_brand_assets([]) }
    assert_raises(NotImplementedError) { abstract_service.generate_content_for_channel("email", "context") }
  end

  test "should allow subclasses to implement interface methods" do
    # Our TestAiService should work
    assert_equal "Test generated content for: hello", @service.generate_content("hello")
    assert_equal({"plan" => "Test campaign plan for Test Campaign"}, 
                @service.generate_campaign_plan({name: "Test Campaign"}))
    assert_equal({"analysis" => "Test analysis of 2 assets"}, 
                @service.analyze_brand_assets([1, 2]))
    assert_equal "Test email content for: Brand context", 
                @service.generate_content_for_channel("email", "Brand context")
  end
end