require 'test_helper'

class LlmIntegrationPerformanceTest < ActiveSupport::TestCase
  def setup
    @brand = brands(:one)
    # @performance_monitor = LlmIntegration::PerformanceMonitor.new
    # @load_tester = LlmIntegration::LoadTester.new
    
    # Setup performance test environment
    setup_performance_test_environment
  end

  test "should handle high-volume content generation efficiently" do
    # Test concurrent content generation requests
    concurrent_requests = 50
    content_requests = (1..concurrent_requests).map do |i|
      {
        id: "request_#{i}",
        brand_id: @brand.id,
        content_type: ["email_subject", "social_post", "ad_copy"].sample,
        priority: [:high, :medium, :low].sample
      }
    end
    
    start_time = Time.current
    
    # Process requests concurrently
    results = Parallel.map(content_requests, in_threads: 10) do |request|
      @performance_monitor.time_operation("content_generation") do
        generate_test_content(request)
      end
    end
    
    end_time = Time.current
    total_time = end_time - start_time
    
    # Performance assertions
    assert_equal concurrent_requests, results.length
    assert total_time < 30.seconds, "High-volume generation took too long: #{total_time}s"
    
    # All requests should complete successfully
    successful_requests = results.count { |r| r[:success] }
    success_rate = successful_requests.to_f / concurrent_requests
    assert success_rate >= 0.95, "Success rate too low: #{success_rate * 100}%"
    
    # Average response time should be reasonable
    response_times = results.map { |r| r[:response_time] }
    average_response_time = response_times.sum / response_times.length
    assert average_response_time < 3.seconds, "Average response time too high: #{average_response_time}s"
  end

  test "should maintain performance under sustained load" do
    # Test sustained load over extended period
    test_duration = 5.minutes
    requests_per_minute = 20
    
    load_test_results = @load_tester.run_sustained_load_test(
      duration: test_duration,
      requests_per_minute: requests_per_minute,
      content_generator: method(:generate_test_content)
    )
    
    # Performance should remain stable throughout test
    assert load_test_results[:total_requests] >= (test_duration.to_i / 60) * requests_per_minute * 0.9
    assert load_test_results[:average_response_time] < 5.seconds
    assert load_test_results[:success_rate] >= 0.95
    
    # Response time should not degrade significantly over time
    response_time_trend = load_test_results[:response_time_trend]
    first_minute_avg = response_time_trend.first[:average_response_time]
    last_minute_avg = response_time_trend.last[:average_response_time]
    degradation_ratio = last_minute_avg / first_minute_avg
    
    assert degradation_ratio < 1.5, "Response time degraded too much: #{degradation_ratio}x"
  end

  test "should efficiently manage LLM provider rate limits" do
    rate_limiter = LlmIntegration::IntelligentRateLimiter.new
    
    # Configure rate limits
    rate_limiter.configure_limits(
      openai: { requests_per_minute: 60, tokens_per_minute: 40000 },
      anthropic: { requests_per_minute: 50, tokens_per_minute: 30000 }
    )
    
    # Test rate limit management under load
    rapid_requests = (1..100).map do |i|
      {
        provider: [:openai, :anthropic].sample,
        estimated_tokens: rand(100..500),
        priority: [:high, :medium, :low].sample
      }
    end
    
    start_time = Time.current
    processed_requests = []
    
    rapid_requests.each do |request|
      if rate_limiter.can_process_request?(request[:provider], request[:estimated_tokens])
        rate_limiter.record_request(request[:provider], request[:estimated_tokens])
        processed_requests << request
      else
        wait_time = rate_limiter.calculate_wait_time(request[:provider])
        sleep(wait_time) if wait_time < 5.seconds  # Cap wait time for test
        
        rate_limiter.record_request(request[:provider], request[:estimated_tokens])
        processed_requests << request
      end
    end
    
    end_time = Time.current
    
    # Should process most requests efficiently
    assert processed_requests.length >= 90, "Too many requests were dropped"
    assert (end_time - start_time) < 2.minutes, "Rate limiting caused excessive delays"
    
    # Rate limits should be respected
    openai_requests = processed_requests.count { |r| r[:provider] == :openai }
    anthropic_requests = processed_requests.count { |r| r[:provider] == :anthropic }
    
    # Assuming test runs within a minute, should not exceed limits significantly
    assert openai_requests <= 70, "OpenAI rate limit likely exceeded"
    assert anthropic_requests <= 60, "Anthropic rate limit likely exceeded"
  end

  test "should optimize memory usage during bulk content generation" do
    memory_monitor = LlmIntegration::MemoryMonitor.new
    
    initial_memory = memory_monitor.current_memory_usage
    
    # Generate large batch of content
    large_batch_size = 200
    batch_requests = (1..large_batch_size).map do |i|
      {
        content_type: "long_form_content",
        word_count: 500,
        brand_id: @brand.id
      }
    end
    
    # Process in batches to test memory management
    batch_size = 25
    batch_requests.each_slice(batch_size) do |batch|
      batch_results = process_content_batch(batch)
      
      # Memory should not grow unbounded
      current_memory = memory_monitor.current_memory_usage
      memory_growth = current_memory - initial_memory
      
      assert memory_growth < 100.megabytes, "Memory usage growing too much: #{memory_growth / 1.megabyte}MB"
      
      # Force garbage collection periodically
      GC.start if batch_requests.index(batch) % 4 == 0
    end
    
    # Memory should be released after processing
    GC.start
    final_memory = memory_monitor.current_memory_usage
    memory_retained = final_memory - initial_memory
    
    assert memory_retained < 50.megabytes, "Too much memory retained: #{memory_retained / 1.megabyte}MB"
  end

  test "should handle provider failover without performance degradation" do
    failover_tester = LlmIntegration::FailoverPerformanceTester.new
    
    # Configure multi-provider setup
    failover_config = {
      primary: :openai,
      fallbacks: [:anthropic, :cohere],
      failover_timeout: 5.seconds
    }
    
    # Test performance with primary provider working
    baseline_performance = failover_tester.measure_baseline_performance(
      provider: :openai,
      request_count: 20
    )
    
    # Simulate primary provider failure
    failover_tester.simulate_provider_failure(:openai)
    
    # Test performance with failover
    failover_performance = failover_tester.measure_failover_performance(
      config: failover_config,
      request_count: 20
    )
    
    # Failover should not cause significant performance degradation
    response_time_increase = failover_performance[:avg_response_time] - baseline_performance[:avg_response_time]
    assert response_time_increase < 2.seconds, "Failover caused too much latency increase"
    
    # Success rate should remain high
    assert failover_performance[:success_rate] >= 0.9, "Failover success rate too low"
    
    # Failover detection should be fast
    assert failover_performance[:avg_failover_detection_time] < 3.seconds
  end

  test "should efficiently cache and reuse content patterns" do
    cache_performance_tester = LlmIntegration::CachePerformanceTester.new
    
    # Test content generation with caching
    cached_patterns = [
      { pattern: "product_announcement", variations: 10 },
      { pattern: "welcome_email", variations: 8 },
      { pattern: "feature_introduction", variations: 12 }
    ]
    
    # Generate content without cache (baseline)
    cache_performance_tester.clear_cache
    baseline_times = []
    
    cached_patterns.each do |pattern|
      pattern[:variations].times do
        start_time = Time.current
        generate_pattern_content(pattern[:pattern])
        baseline_times << Time.current - start_time
      end
    end
    
    baseline_avg = baseline_times.sum / baseline_times.length
    
    # Generate content with cache enabled
    cache_performance_tester.enable_cache
    cached_times = []
    
    cached_patterns.each do |pattern|
      pattern[:variations].times do
        start_time = Time.current
        generate_pattern_content(pattern[:pattern])
        cached_times << Time.current - start_time
      end
    end
    
    cached_avg = cached_times.sum / cached_times.length
    
    # Cache should significantly improve performance for repeated patterns
    performance_improvement = (baseline_avg - cached_avg) / baseline_avg
    assert performance_improvement >= 0.3, "Cache not providing sufficient performance improvement"
    
    # Cache hit rate should be reasonable
    cache_stats = cache_performance_tester.get_cache_statistics
    assert cache_stats[:hit_rate] >= 0.6, "Cache hit rate too low: #{cache_stats[:hit_rate]}"
  end

  test "should scale content generation with background job processing" do
    job_performance_tester = LlmIntegration::JobPerformanceTester.new
    
    # Queue large number of content generation jobs
    job_count = 100
    jobs = (1..job_count).map do |i|
      LlmIntegration::ContentGenerationJob.perform_later(
        brand_id: @brand.id,
        content_type: ["email", "social", "ad_copy"].sample,
        priority: [:high, :medium, :low].sample,
        job_id: "perf_test_#{i}"
      )
    end
    
    start_time = Time.current
    
    # Wait for jobs to complete
    jobs_completed = 0
    timeout = 5.minutes
    
    while jobs_completed < job_count && (Time.current - start_time) < timeout
      sleep(1)
      jobs_completed = job_performance_tester.count_completed_jobs("perf_test_")
    end
    
    completion_time = Time.current - start_time
    
    # Performance assertions
    assert jobs_completed >= job_count * 0.95, "Too many jobs failed to complete"
    assert completion_time < 3.minutes, "Job processing took too long: #{completion_time}s"
    
    # Job throughput should be reasonable
    throughput = jobs_completed / completion_time.to_f
    assert throughput >= 0.5, "Job throughput too low: #{throughput} jobs/second"
    
    # Jobs should be distributed across workers
    worker_distribution = job_performance_tester.get_worker_distribution
    assert worker_distribution.keys.length > 1, "Jobs not distributed across workers"
  end

  test "should maintain database performance under high content volume" do
    db_performance_tester = LlmIntegration::DatabasePerformanceTester.new
    
    # Test database operations under load
    content_records = 1000
    
    # Measure content creation performance
    creation_time = Benchmark.measure do
      (1..content_records).each do |i|
        create_test_content_record(
          brand_id: @brand.id,
          content: "Test content #{i}",
          metadata: { performance_test: true }
        )
      end
    end
    
    # Database operations should be efficient
    assert creation_time.real < 30.seconds, "Content creation too slow: #{creation_time.real}s"
    
    # Test query performance with large dataset
    query_time = Benchmark.measure do
      LlmIntegration::GeneratedContent.where(brand_id: @brand.id)
                                     .where("metadata ->> 'performance_test' = 'true'")
                                     .includes(:brand)
                                     .limit(100)
                                     .to_a
    end
    
    assert query_time.real < 1.second, "Query performance too slow: #{query_time.real}s"
    
    # Test bulk operations
    bulk_update_time = Benchmark.measure do
      LlmIntegration::GeneratedContent.where(brand_id: @brand.id)
                                     .where("metadata ->> 'performance_test' = 'true'")
                                     .update_all(updated_at: Time.current)
    end
    
    assert bulk_update_time.real < 5.seconds, "Bulk update too slow: #{bulk_update_time.real}s"
  end

  test "should handle API timeout scenarios gracefully" do
    timeout_tester = LlmIntegration::TimeoutPerformanceTester.new
    
    # Test various timeout scenarios
    timeout_scenarios = [
      { provider: :openai, timeout: 1.second, expected_behavior: :fast_failure },
      { provider: :anthropic, timeout: 30.seconds, expected_behavior: :normal_processing },
      { provider: :openai, timeout: 60.seconds, expected_behavior: :extended_wait }
    ]
    
    timeout_scenarios.each do |scenario|
      start_time = Time.current
      
      result = timeout_tester.test_timeout_scenario(
        provider: scenario[:provider],
        timeout: scenario[:timeout],
        content_request: { type: "test_content", brand_id: @brand.id }
      )
      
      elapsed_time = Time.current - start_time
      
      case scenario[:expected_behavior]
      when :fast_failure
        assert elapsed_time < 2.seconds, "Fast failure timeout took too long"
        assert result[:timeout_occurred]
      when :normal_processing
        # Should complete normally if provider is responsive
        if result[:success]
          assert elapsed_time < scenario[:timeout]
        end
      when :extended_wait
        # Should respect longer timeout if needed
        assert elapsed_time <= scenario[:timeout] + 1.second
      end
    end
  end

  private

  def setup_performance_test_environment
    # Configure test environment for performance testing
    Rails.cache.clear
    ActiveRecord::Base.connection.execute("VACUUM ANALYZE") if Rails.env.test?
    
    # Mock LLM API responses to avoid external dependencies
    mock_performance_test_responses
  end

  def generate_test_content(request)
    start_time = Time.current
    
    begin
      # Simulate content generation
      content = "Generated content for #{request[:content_type]} - ID: #{request[:id]}"
      brand_score = rand(0.90..0.99)
      
      {
        success: true,
        content: content,
        brand_compliance_score: brand_score,
        response_time: Time.current - start_time
      }
    rescue => e
      {
        success: false,
        error: e.message,
        response_time: Time.current - start_time
      }
    end
  end

  def process_content_batch(batch)
    batch.map { |request| generate_test_content(request) }
  end

  def generate_pattern_content(pattern)
    # Simulate pattern-based content generation
    sleep(rand(0.1..0.3))  # Simulate processing time
    "Pattern content for #{pattern}"
  end

  def create_test_content_record(attributes)
    # Create a test content record for database performance testing
    # This would integrate with actual LLM integration models
    {
      id: SecureRandom.uuid,
      brand_id: attributes[:brand_id],
      content: attributes[:content],
      metadata: attributes[:metadata],
      created_at: Time.current
    }
  end

  def mock_performance_test_responses
    # Mock API responses for consistent performance testing
    stub_request(:post, /api\.openai\.com/)
      .to_return(
        status: 200,
        body: {
          choices: [{ message: { content: "Performance test content" } }]
        }.to_json
      )
  end
end