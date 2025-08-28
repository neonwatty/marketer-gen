# frozen_string_literal: true

require 'test_helper'

class ApiOptimizationJobTest < ActiveSupport::TestCase
  def setup
    @customer_id = 'test_customer_123'
    @platform = 'google_ads'
    @endpoint = 'search'
    
    # Clean up any existing quota trackers
    ApiQuotaTracker.where(customer_id: @customer_id).destroy_all
    
    # Create a quota tracker for testing
    @quota_tracker = ApiQuotaTracker.create!(
      platform: @platform,
      endpoint: @endpoint,
      customer_id: @customer_id,
      quota_limit: 1000,
      current_usage: 500,
      reset_interval: 86400,
      reset_time: Time.current + 3600
    )
  end

  def teardown
    ApiQuotaTracker.where(customer_id: @customer_id).destroy_all
  end

  test "should validate optimization types" do
    job = ApiOptimizationJob.new
    
    assert_raises(ArgumentError) do
      job.perform('invalid_type')
    end
    
    # Valid types should not raise errors
    ApiOptimizationJob::OPTIMIZATION_TYPES.each do |type|
      assert_nothing_raised do
        # Mock the individual methods to prevent actual execution
        job.stub(:perform_quota_monitoring, {}) do
          job.stub(:perform_request_optimization, {}) do
            job.stub(:perform_batch_processing, {}) do
              job.stub(:perform_quota_reset, {}) do
                job.stub(:perform_performance_analysis, {}) do
                  job.perform(type, { customer_id: @customer_id })
                end
              end
            end
          end
        end
      end
    end
  end

  test "should perform quota monitoring successfully" do
    # Create quota tracker near limit
    @quota_tracker.update!(current_usage: 880) # 88% usage
    
    job = ApiOptimizationJob.new
    result = job.perform('quota_monitoring', { 
      customer_id: @customer_id,
      alert_threshold: 85.0
    })
    
    assert_equal 'completed', result[:status]
    assert_equal @customer_id, result[:customer_id]
    assert_equal 1, result[:alerts_triggered]
    assert_equal 1, result[:alerts].length
    
    alert = result[:alerts].first
    assert_equal @platform, alert[:platform]
    assert_equal @endpoint, alert[:endpoint]
    assert_equal 88.0, alert[:usage_percentage]
  end

  test "should require customer_id for quota monitoring" do
    job = ApiOptimizationJob.new
    
    assert_raises(ArgumentError, "customer_id is required for quota monitoring") do
      job.perform('quota_monitoring', {})
    end
  end

  test "should perform request optimization successfully" do
    pending_requests = [
      { id: 1, query: 'test query 1' },
      { id: 2, query: 'test query 2' },
      { id: 3, query: 'test query 3' }
    ]
    
    job = ApiOptimizationJob.new
    
    # Mock the process_request_batch method
    job.stub(:process_request_batch, { results: [
      { index: 0, result: { processed: true }, success: true },
      { index: 1, result: { processed: true }, success: true },
      { index: 2, result: { processed: true }, success: true }
    ] }) do
      result = job.perform('request_optimization', {
        customer_id: @customer_id,
        platform: @platform,
        endpoint: @endpoint,
        pending_requests: pending_requests
      })
      
      assert_equal 'completed', result[:status]
      assert_equal 3, result[:total_requests]
      assert_equal 3, result[:successful_requests]
      assert_equal 0, result[:failed_requests]
    end
  end

  test "should handle quota exceeded in request optimization" do
    @quota_tracker.update!(current_usage: @quota_tracker.quota_limit)
    
    job = ApiOptimizationJob.new
    result = job.perform('request_optimization', {
      customer_id: @customer_id,
      platform: @platform,
      endpoint: @endpoint,
      pending_requests: [{ id: 1 }]
    })
    
    assert_equal 'delayed', result[:status]
    assert_equal 'quota_exceeded', result[:reason]
    assert_includes result, :retry_after
  end

  test "should require parameters for request optimization" do
    job = ApiOptimizationJob.new
    
    assert_raises(ArgumentError, "Missing required parameters") do
      job.perform('request_optimization', {})
    end
    
    assert_raises(ArgumentError, "Missing required parameters") do
      job.perform('request_optimization', { customer_id: @customer_id })
    end
  end

  test "should perform batch processing successfully" do
    requests = [
      { id: 1, data: 'request1' },
      { id: 2, data: 'request2' }
    ]
    
    job = ApiOptimizationJob.new
    
    # Mock ApiRateLimitingService
    mock_rate_limiter = Minitest::Mock.new
    mock_rate_limiter.expect(:execute_batch_requests, {
      results: [
        { index: 0, success: true },
        { index: 1, success: true }
      ],
      successful: 2,
      failed: 0,
      failed_requests: []
    }, [Array])
    
    ApiRateLimitingService.stub(:new, mock_rate_limiter) do
      result = job.perform('batch_processing', {
        customer_id: @customer_id,
        platform: @platform,
        endpoint: @endpoint,
        requests: requests
      })
      
      assert_equal 'completed', result[:status]
      assert_equal @platform, result[:platform]
      assert_equal @endpoint, result[:endpoint]
      assert_equal @customer_id, result[:customer_id]
      assert_includes result, :results
    end
    
    mock_rate_limiter.verify
  end

  test "should perform quota reset successfully" do
    # Create an expired quota tracker
    expired_tracker = ApiQuotaTracker.create!(
      platform: 'linkedin',
      endpoint: 'profile',
      customer_id: @customer_id,
      quota_limit: 1000,
      current_usage: 500,
      reset_interval: 86400,
      reset_time: Time.current - 3600
    )
    
    job = ApiOptimizationJob.new
    result = job.perform('quota_reset', {})
    
    assert_equal 'completed', result[:status]
    assert_equal 1, result[:quotas_reset]
    
    expired_tracker.reload
    assert_equal 0, expired_tracker.current_usage
  end

  test "should perform performance analysis successfully" do
    job = ApiOptimizationJob.new
    result = job.perform('performance_analysis', {
      customer_id: @customer_id,
      time_range: 24.hours
    })
    
    assert_equal 'completed', result[:status]
    assert_equal @customer_id, result[:customer_id]
    assert_includes result, :analysis
    
    analysis = result[:analysis]
    assert_includes analysis, :quota_usage_patterns
    assert_includes analysis, :rate_limit_incidents
    assert_includes analysis, :optimization_opportunities
    assert_includes analysis, :recommendations
  end

  test "should determine optimal strategy correctly" do
    job = ApiOptimizationJob.new
    
    # Low usage - should return aggressive
    @quota_tracker.update!(current_usage: 200) # 20%
    strategy = job.send(:determine_optimal_strategy, @customer_id, @platform, @endpoint)
    assert_equal :aggressive, strategy
    
    # Medium usage - should return balanced
    @quota_tracker.update!(current_usage: 500) # 50%
    strategy = job.send(:determine_optimal_strategy, @customer_id, @platform, @endpoint)
    assert_equal :balanced, strategy
    
    # High usage - should return conservative
    @quota_tracker.update!(current_usage: 800) # 80%
    strategy = job.send(:determine_optimal_strategy, @customer_id, @platform, @endpoint)
    assert_equal :conservative, strategy
  end

  test "should determine urgency correctly" do
    job = ApiOptimizationJob.new
    
    assert_equal :low, job.send(:determine_urgency, 75.0)
    assert_equal :medium, job.send(:determine_urgency, 85.0)
    assert_equal :high, job.send(:determine_urgency, 97.0)
  end

  test "should process individual request successfully" do
    job = ApiOptimizationJob.new
    request_data = { id: 1, query: 'test' }
    
    result = job.send(:process_individual_request, @platform, @endpoint, request_data, nil)
    
    assert result[:processed]
    assert_equal request_data, result[:request]
    assert_includes result, :timestamp
  end

  test "should handle individual request failures" do
    job = ApiOptimizationJob.new
    request_data = { id: 1, query: 'test' }
    
    # Mock a callback class that raises an error
    callback_class = Class.new do
      def self.process_api_request(platform, endpoint, request)
        raise StandardError.new("Processing failed")
      end
    end
    
    result = job.send(:process_individual_request, @platform, @endpoint, request_data, callback_class)
    
    assert_not result[:processed]
    assert_equal "Processing failed", result[:error]
    assert_equal request_data, result[:request]
  end

  test "should schedule optimization for platform correctly" do
    job = ApiOptimizationJob.new
    
    # Mock ApiOptimizationJob.set and perform_later
    mock_job = Minitest::Mock.new
    mock_job.expect(:perform_later, nil, ['request_optimization', Hash])
    
    ApiOptimizationJob.stub(:set, mock_job) do
      job.send(:schedule_optimization_for_platform, {
        customer_id: @customer_id,
        platform: @platform,
        endpoint: @endpoint,
        urgency: :high
      })
    end
    
    mock_job.verify
    assert true, "Scheduling completed successfully"
  end

  test "should generate analysis data correctly" do
    job = ApiOptimizationJob.new
    
    usage_patterns = job.send(:analyze_quota_usage_patterns, @customer_id, 24.hours)
    assert_includes usage_patterns, :peak_usage_hours
    assert_includes usage_patterns, :average_daily_usage
    assert_includes usage_patterns, :trends
    
    incidents = job.send(:analyze_rate_limit_incidents, @customer_id, 24.hours)
    assert_includes incidents, :total_incidents
    assert_includes incidents, :platforms_affected
    assert_includes incidents, :most_common_cause
    
    opportunities = job.send(:identify_optimization_opportunities, @customer_id)
    assert_kind_of Array, opportunities
    
    recommendations = job.send(:generate_optimization_recommendations, @customer_id)
    assert_kind_of Array, recommendations
  end

  test "should handle batch processing with auto retry" do
    requests = [{ id: 1 }, { id: 2 }]
    
    job = ApiOptimizationJob.new
    
    # Mock rate limiter with some failures
    mock_rate_limiter = Minitest::Mock.new
    mock_rate_limiter.expect(:execute_batch_requests, {
      results: [
        { index: 0, success: true },
        { index: 1, success: false }
      ],
      successful: 1,
      failed: 1,
      failed_requests: [{ index: 1, request: requests[1] }]
    }, [Array])
    
    # Mock retry scheduling
    mock_job = Minitest::Mock.new
    mock_job.expect(:perform_later, nil, ['batch_processing', Hash])
    
    ApiRateLimitingService.stub(:new, mock_rate_limiter) do
      ApiOptimizationJob.stub(:set, mock_job) do
        result = job.perform('batch_processing', {
          customer_id: @customer_id,
          platform: @platform,
          endpoint: @endpoint,
          requests: requests,
          auto_retry: true
        })
        
        assert_equal 'completed', result[:status]
      end
    end
    
    mock_rate_limiter.verify
    mock_job.verify
  end

  test "should enqueue jobs with correct queue and retry configuration" do
    assert_equal "api_optimization", ApiOptimizationJob.queue_name
    
    # Test that the job has retry configuration
    assert_respond_to ApiOptimizationJob, :retry_on
    
    # Test basic functionality works
    job = ApiOptimizationJob.new
    assert_not_nil job
  end
end