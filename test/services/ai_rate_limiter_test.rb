require "test_helper"

class AiRateLimiterTest < ActiveSupport::TestCase
  class TestService < AiServiceBase
    include AiRateLimiter

    def initialize(attributes = {})
      super(attributes.merge(
        provider_name: "test_provider",
        model_name: "test_model",
        rate_limit_enabled: true,
        rate_limit_requests_per_minute: 5,
        rate_limit_requests_per_hour: 20,
        rate_limit_tokens_per_minute: 1000
      ))
    end
  end

  setup do
    @service = TestService.new
    Rails.cache.clear
    Rails.logger.level = :debug
  end

  test "allows requests within rate limits" do
    # Should allow request within limits
    assert_nothing_raised do
      @service.check_rate_limits!(100)
    end

    # Record the request
    @service.record_rate_limit_usage(100)

    # Should still allow more requests within limit
    assert_nothing_raised do
      @service.check_rate_limits!(100)
    end
  end

  test "blocks requests exceeding minute rate limit" do
    # Make requests up to the limit
    5.times do |i|
      @service.check_rate_limits!(100)
      @service.record_rate_limit_usage(100)
    end

    # Next request should be blocked
    assert_raises(AiRateLimiter::RateLimitExceededError) do
      @service.check_rate_limits!(100)
    end
  end

  test "blocks requests exceeding token rate limit" do
    # Request with tokens exceeding limit
    assert_raises(AiRateLimiter::RateLimitExceededError) do
      @service.check_rate_limits!(1500) # Exceeds 1000 token limit
    end
  end

  test "rate limit status returns correct information" do
    # Make some requests
    @service.check_rate_limits!(100)
    @service.record_rate_limit_usage(100)

    status = @service.rate_limit_status

    assert status[:enabled]
    assert_equal 5, status[:limits][:requests_per_minute]
    assert_equal 20, status[:limits][:requests_per_hour]
    assert_equal 1000, status[:limits][:tokens_per_minute]
    
    assert_equal 1, status[:requests][:minute]
    assert_equal 100, status[:tokens][:minute]
  end

  test "rate limiting can be disabled" do
    service = TestService.new
    service.rate_limit_enabled = false
    
    # Should allow any number of requests when disabled
    assert_nothing_raised do
      10.times do |i|
        service.check_rate_limits!(1000)
        service.record_rate_limit_usage(1000)
      end
    end

    status = service.rate_limit_status
    assert_not status[:enabled]
  end

  test "rate limit counters increment correctly" do
    initial_status = @service.rate_limit_status

    # Make a request with tokens
    @service.check_rate_limits!(200)
    @service.record_rate_limit_usage(200)

    updated_status = @service.rate_limit_status

    # Counters should have incremented
    assert_equal initial_status[:requests][:minute] + 1, updated_status[:requests][:minute]
    assert_equal initial_status[:tokens][:minute] + 200, updated_status[:tokens][:minute]
  end

  test "rate limit error includes retry_after information" do
    # Hit the rate limit
    5.times do |i|
      @service.check_rate_limits!(100)
      @service.record_rate_limit_usage(100)
    end

    # Next request should include retry information
    error = assert_raises(AiRateLimiter::RateLimitExceededError) do
      @service.check_rate_limits!(100)
    end

    assert error.retry_after
    assert error.limit
    assert error.remaining
    assert_equal 5, error.limit
    assert_equal 0, error.remaining
  end

  teardown do
    Rails.cache.clear
  end
end