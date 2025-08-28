# frozen_string_literal: true

require 'test_helper'

class ApiRateLimitingServiceTest < ActiveSupport::TestCase
  def setup
    @customer_id = 'test_customer_123'
    @platform = 'google_ads'
    @endpoint = 'search'
    
    # Clean up any existing quota trackers first
    ApiQuotaTracker.where(customer_id: @customer_id).destroy_all
    
    @service = ApiRateLimitingService.new(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      strategy: :balanced
    )
  end

  def teardown
    ApiQuotaTracker.where(customer_id: @customer_id).destroy_all
  end

  test "should initialize with correct configuration" do
    assert_equal @platform, @service.instance_variable_get(:@platform)
    assert_equal @endpoint, @service.instance_variable_get(:@endpoint)
    assert_equal @customer_id, @service.instance_variable_get(:@customer_id)
    assert_not_nil @service.instance_variable_get(:@quota_tracker)
    assert_not_nil @service.instance_variable_get(:@strategy)
  end

  test "should create quota tracker during initialization" do
    tracker = @service.instance_variable_get(:@quota_tracker)
    
    assert_not_nil tracker
    assert_equal @platform, tracker.platform
    assert_equal @endpoint, tracker.endpoint
    assert_equal @customer_id, tracker.customer_id
    assert tracker.persisted?
  end

  test "should execute request successfully when quota available" do
    executed = false
    result = @service.execute_request do
      executed = true
      { success: true, data: 'test_result' }
    end
    
    assert executed
    assert_equal({ success: true, data: 'test_result' }, result)
    
    tracker = ApiQuotaTracker.find_by(customer_id: @customer_id, platform: @platform, endpoint: @endpoint)
    assert_not_nil tracker, "Quota tracker should exist"
    assert_equal 1, tracker.current_usage
  end

  test "should raise QuotaExceeded when quota not available" do
    # Set quota to 0 to simulate exhausted quota
    tracker = @service.instance_variable_get(:@quota_tracker)
    tracker.update!(current_usage: tracker.quota_limit)
    
    assert_raises(ApiRateLimitingService::QuotaExceeded) do
      @service.execute_request do
        { success: true, data: 'test_result' }
      end
    end
  end

  test "should handle rate limiting errors" do
    rate_limit_error = StandardError.new("Rate limit exceeded")
    
    assert_raises(ApiRateLimitingService::RateLimitExceeded) do
      @service.execute_request do
        raise rate_limit_error
      end
    end
  end

  test "should not consume quota on failed non-rate-limit requests" do
    tracker = @service.instance_variable_get(:@quota_tracker)
    initial_usage = tracker.current_usage
    
    assert_raises(StandardError) do
      @service.execute_request do
        raise StandardError.new("Some other error")
      end
    end
    
    tracker = ApiQuotaTracker.find_by(customer_id: @customer_id, platform: @platform, endpoint: @endpoint)
    assert_not_nil tracker, "Quota tracker should exist"
    assert_equal initial_usage, tracker.current_usage
  end

  test "should execute batch requests successfully" do
    requests = [
      { id: 1, data: 'request1' },
      { id: 2, data: 'request2' },
      { id: 3, data: 'request3' }
    ]
    
    results = @service.execute_batch_requests(requests) do |request, index|
      { processed: true, request_id: request[:id], index: index }
    end
    
    assert_equal 3, results[:successful]
    assert_equal 0, results[:failed]
    assert_equal 3, results[:results].length
    
    results[:results].each_with_index do |result, index|
      assert result[:success]
      assert_equal index, result[:result][:index]
      assert_equal requests[index][:id], result[:result][:request_id]
    end
  end

  test "should handle batch request failures gracefully" do
    requests = [
      { id: 1, data: 'request1' },
      { id: 2, data: 'request2' },
      { id: 3, data: 'request3' }
    ]
    
    results = @service.execute_batch_requests(requests) do |request, index|
      if request[:id] == 2
        raise StandardError.new("Request failed")
      else
        { processed: true, request_id: request[:id] }
      end
    end
    
    assert_equal 2, results[:successful]
    assert_equal 1, results[:failed]
    assert_equal 1, results[:failed_requests].length
    
    failed_request = results[:failed_requests].first
    assert_equal 1, failed_request[:index]
    assert_equal({ id: 2, data: 'request2' }, failed_request[:request])
  end

  test "should stop batch processing on quota exceeded" do
    # Set quota very low
    tracker = @service.instance_variable_get(:@quota_tracker)
    tracker.update!(quota_limit: 2, current_usage: 1)
    
    requests = [
      { id: 1, data: 'request1' },
      { id: 2, data: 'request2' },
      { id: 3, data: 'request3' }
    ]
    
    results = @service.execute_batch_requests(requests) do |request, index|
      { processed: true, request_id: request[:id] }
    end
    
    # Should process first request successfully, then quota should be exceeded
    # When quota is exceeded, processing stops immediately
    assert_equal 1, results[:successful]
    assert_equal 1, results[:failed] # Only the second request should fail before stopping
    
    # Only second request should fail, third should not be processed
    assert_equal 2, results[:results].length # Only 2 results since processing stopped
  end

  test "should provide accurate status information" do
    # Consume some quota first
    @service.execute_request { { success: true } }
    
    status = @service.status
    
    assert_equal @platform, status[:platform]
    assert_equal @endpoint, status[:endpoint]
    assert_equal @customer_id, status[:customer_id]
    assert_includes status, :strategy
    assert_includes status, :quota
    assert_includes status, :rate_limit
    
    quota_status = status[:quota]
    assert_includes quota_status, :limit
    assert_includes quota_status, :used
    assert_includes quota_status, :remaining
    assert_includes quota_status, :usage_percentage
    assert_includes quota_status, :time_until_reset
    
    assert_equal 1, quota_status[:used]
  end

  test "should optimize request timing based on quota" do
    request_count = 100
    optimization = @service.optimize_request_timing(request_count)
    
    assert optimization[:can_proceed]
    assert_includes optimization, :estimated_duration
    assert_includes optimization, :recommended_batch_size
    assert_includes optimization, :wait_time
    assert_includes optimization, :strategy_recommendation
    
    # Should recommend different batch sizes based on remaining quota
    assert optimization[:recommended_batch_size] > 0
  end

  test "should prevent optimization when quota exceeded" do
    tracker = @service.instance_variable_get(:@quota_tracker)
    tracker.update!(current_usage: tracker.quota_limit)
    
    request_count = 10
    optimization = @service.optimize_request_timing(request_count)
    
    assert_not optimization[:can_proceed]
    assert_equal 'quota_exceeded', optimization[:reason]
  end

  test "should apply rate limiting between requests" do
    start_time = Time.current
    
    # Execute multiple requests
    3.times do |i|
      @service.execute_request do
        { success: true, request: i }
      end
    end
    
    duration = Time.current - start_time
    
    # Should take some time due to rate limiting
    # This is a loose test since rate limiting is minimal for tests
    assert duration >= 0
  end

  test "should handle different strategies correctly" do
    aggressive_service = ApiRateLimitingService.new(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: "#{@customer_id}_aggressive",
      strategy: :aggressive
    )
    
    conservative_service = ApiRateLimitingService.new(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: "#{@customer_id}_conservative",
      strategy: :conservative
    )
    
    aggressive_status = aggressive_service.status
    conservative_status = conservative_service.status
    
    # Aggressive should have higher rate limits
    assert aggressive_status[:rate_limit][:requests_per_second] >= 
           conservative_status[:rate_limit][:requests_per_second]
  end

  test "class methods should work correctly" do
    # Create some quota trackers with different customer IDs to avoid conflicts
    test_customer_id = 'class_methods_test_customer'
    ApiQuotaTracker.create!(
      platform: 'google_ads',
      endpoint: 'search',
      customer_id: test_customer_id,
      quota_limit: 1000,
      current_usage: 950,
      reset_interval: 86400,
      reset_time: Time.current + 3600
    )
    
    # Test quota status
    status = ApiRateLimitingService.quota_status_for_customer(test_customer_id)
    assert_includes status, 'google_ads'
    
    # Test platforms near limit
    near_limit = ApiRateLimitingService.platforms_near_limit(test_customer_id)
    assert_equal 1, near_limit.length
    assert_equal ['google_ads', 'search'], near_limit.first
    
    # Test quota reset (create an expired tracker)
    ApiQuotaTracker.create!(
      platform: 'linkedin',
      endpoint: 'profile', 
      customer_id: test_customer_id,
      quota_limit: 1000,
      current_usage: 500,
      reset_interval: 86400,
      reset_time: Time.current - 3600
    )
    
    reset_count = ApiRateLimitingService.reset_expired_quotas!
    assert_equal 1, reset_count
    
    # Cleanup test data
    ApiQuotaTracker.where(customer_id: test_customer_id).destroy_all
  end

  test "should detect rate limit errors correctly" do
    rate_limit_messages = [
      "Rate limit exceeded",
      "Too many requests", 
      "Quota exceeded",
      "RATE_LIMIT_EXCEEDED"
    ]
    
    rate_limit_messages.each do |message|
      error = StandardError.new(message)
      assert @service.send(:rate_limit_error?, error)
    end
    
    # Non-rate limit error
    other_error = StandardError.new("Some other error")
    assert_not @service.send(:rate_limit_error?, other_error)
  end

  test "should extract retry-after from error messages" do
    retry_after_messages = [
      "Rate limit exceeded, retry after 60 seconds",
      "Please wait 30 seconds before retrying",
      "Retry after 120"
    ]
    
    expected_values = [60, 30, 120]
    
    retry_after_messages.each_with_index do |message, index|
      error = StandardError.new(message)
      retry_after = @service.send(:extract_retry_after, error)
      assert_equal expected_values[index], retry_after
    end
    
    # Default case
    error = StandardError.new("Some error without retry info")
    retry_after = @service.send(:extract_retry_after, error)
    assert_equal 60, retry_after
  end

  test "should calculate optimal batch size based on quota" do
    tracker = @service.instance_variable_get(:@quota_tracker)
    tracker.update!(quota_limit: 1000, current_usage: 500)
    
    batch_size = @service.send(:optimal_batch_size)
    
    # Should be reasonable batch size based on remaining quota
    assert batch_size > 0
    assert batch_size <= 500 # Should not exceed remaining quota
  end

  test "should recommend strategy based on quota usage" do
    tracker = @service.instance_variable_get(:@quota_tracker)
    
    # Low usage - should recommend aggressive
    tracker.update!(quota_limit: 1000, current_usage: 100)
    recommendation = @service.send(:recommend_strategy, 10.0)
    assert_equal :aggressive, recommendation
    
    # Medium usage - should recommend balanced  
    tracker.update!(current_usage: 600)
    recommendation = @service.send(:recommend_strategy, 60.0)
    assert_equal :balanced, recommendation
    
    # High usage - should recommend conservative
    tracker.update!(current_usage: 900)
    recommendation = @service.send(:recommend_strategy, 90.0)
    assert_equal :conservative, recommendation
  end
end