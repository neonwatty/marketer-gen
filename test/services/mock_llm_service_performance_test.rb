# frozen_string_literal: true

require 'test_helper'

class MockLlmServicePerformanceTest < ActiveSupport::TestCase
  def setup
    @service = MockLlmService.new
  end

  test "should simulate realistic response times" do
    # In test environment, delays are disabled, so we test the delay logic exists
    # by stubbing the delay method and verifying it gets called
    @service.expects(:simulate_delay).once
    @service.generate_social_media_content(platform: 'twitter', topic: 'test')
  end

  test "should occasionally simulate errors" do
    # Test error simulation by stubbing random number generation
    @service.stubs(:should_simulate_error?).returns(true)
    
    assert_raises(StandardError) do
      @service.generate_social_media_content(platform: 'twitter', topic: 'test')
    end
  end

  test "should handle concurrent requests" do
    threads = []
    results = []
    mutex = Mutex.new
    
    10.times do
      threads << Thread.new do
        result = @service.generate_social_media_content(
          platform: 'twitter', 
          topic: 'concurrent test'
        )
        mutex.synchronize { results << result }
      end
    end
    
    threads.each(&:join)
    
    assert_equal 10, results.length
    results.each do |result|
      assert result[:content].present?
      assert result[:metadata].present?
    end
  end

  test "should maintain consistent interface across all methods" do
    methods_to_test = [
      :generate_social_media_content,
      :generate_email_content,
      :generate_ad_copy,
      :generate_landing_page_content,
      :generate_campaign_plan
    ]
    
    methods_to_test.each do |method|
      result = @service.send(method, {})
      
      assert result.is_a?(Hash), "#{method} should return a Hash"
      assert result.key?(:metadata), "#{method} should include metadata"
      assert result[:metadata][:service] == 'mock', "#{method} should identify as mock service"
      assert result[:metadata][:generated_at].present?, "#{method} should include timestamp"
    end
  end

  test "should handle high frequency requests" do
    start_time = Time.current
    
    20.times do
      @service.generate_social_media_content(platform: 'twitter', topic: 'load test')
    end
    
    end_time = Time.current
    total_time = end_time - start_time
    
    # Should complete 20 requests in reasonable time (allowing for delays)
    assert total_time < 60, "20 requests should complete in under 60 seconds"
  end

  test "should vary response times" do
    # In test environment, we verify the random delay range logic exists
    # Test that the delay range is properly configured
    delay_range = @service.instance_variable_get(:@response_delay_range)
    assert_equal (0.5..2.0), delay_range, "Should have configured delay range"
    
    # Test that simulate_delay uses randomization
    @service.expects(:rand).with(delay_range).at_least_once
    @service.send(:simulate_delay)
  end

  test "should handle edge case parameters without performance degradation" do
    edge_cases = [
      { platform: '', topic: '', character_limit: 0 },
      { platform: 'x' * 1000, topic: 'y' * 1000 },
      { brand_context: { keywords: ['a'] * 100 } },
      { brand_context: { voice: 'z' * 500 } }
    ]
    
    edge_cases.each do |params|
      start_time = Time.current
      result = @service.generate_social_media_content(params)
      end_time = Time.current
      
      response_time = end_time - start_time
      assert response_time < 5, "Edge case should not cause significant performance degradation"
      assert result[:content].present?, "Should still generate content for edge cases"
    end
  end

  test "should maintain memory usage across multiple calls" do
    # Ruby doesn't have direct memory measurement, but we can check for obvious leaks
    initial_objects = ObjectSpace.count_objects
    
    100.times do
      @service.generate_social_media_content(platform: 'twitter', topic: 'memory test')
    end
    
    final_objects = ObjectSpace.count_objects
    
    # Object count shouldn't grow dramatically (allowing for some GC variance)
    object_growth = final_objects[:TOTAL] - initial_objects[:TOTAL]
    assert object_growth < 10000, "Should not create excessive objects (created #{object_growth})"
  end

  test "should handle error simulation consistently" do
    error_count = 0
    success_count = 0
    
    # Run many requests to test error rate
    100.times do
      begin
        @service.generate_social_media_content(platform: 'twitter', topic: 'error test')
        success_count += 1
      rescue StandardError
        error_count += 1
      end
    end
    
    total_requests = error_count + success_count
    error_rate = error_count.to_f / total_requests
    
    # Error rate should be approximately 2% (allowing for statistical variance)
    assert error_rate < 0.1, "Error rate should be reasonable (was #{error_rate * 100}%)"
    assert success_count > 0, "Should have some successful requests"
  end
end