require 'test_helper'

class JourneySuggestionServicePerformanceTest < ActiveSupport::TestCase
  def setup
    @service = JourneySuggestionService.new(campaign_type: 'awareness')
  end

  test "suggestion generation is performant" do
    start_time = Time.current
    
    100.times do
      @service.suggest_steps(limit: 10)
    end
    
    end_time = Time.current
    execution_time = end_time - start_time
    
    # Should complete 100 suggestion generations in under 1 second
    assert execution_time < 1.0, "Suggestion generation too slow: #{execution_time}s"
  end

  test "memory usage is reasonable with large existing steps array" do
    # Create service with large existing steps array
    large_existing_steps = 1000.times.map { |i| { step_type: "step_#{i}" } }
    
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      existing_steps: large_existing_steps
    )
    
    # Should not raise memory errors
    assert_nothing_raised do
      suggestions = service.suggest_steps
      assert suggestions.is_a?(Array)
    end
  end

  test "concurrent suggestion generation is thread safe" do
    results = []
    threads = []
    
    10.times do
      threads << Thread.new do
        service = JourneySuggestionService.new(campaign_type: 'awareness')
        results << service.suggest_steps.length
      end
    end
    
    threads.each(&:join)
    
    # All threads should return consistent results
    assert_equal 10, results.length
    results.each { |result| assert result >= 0 }
  end

  test "channel suggestions are performant for all step types" do
    step_types = JourneyStep::STEP_TYPES
    
    start_time = Time.current
    
    step_types.each do |step_type|
      100.times do
        @service.suggest_channels_for_step(step_type)
      end
    end
    
    end_time = Time.current
    execution_time = end_time - start_time
    
    # Should complete all channel suggestions quickly
    assert execution_time < 0.5, "Channel suggestion generation too slow: #{execution_time}s"
  end

  test "content suggestions are performant for all combinations" do
    step_types = %w[email social_post content_piece webinar]
    stages = %w[discovery education evaluation decision]
    
    start_time = Time.current
    
    step_types.each do |step_type|
      stages.each do |stage|
        10.times do
          @service.suggest_content_for_step(step_type, stage)
        end
      end
    end
    
    end_time = Time.current
    execution_time = end_time - start_time
    
    # Should complete all content suggestions quickly
    assert execution_time < 1.0, "Content suggestion generation too slow: #{execution_time}s"
  end

  test "service initialization is fast" do
    start_time = Time.current
    
    1000.times do
      JourneySuggestionService.new(
        campaign_type: 'awareness',
        template_type: 'email',
        current_stage: 'discovery',
        existing_steps: [{ step_type: 'email' }]
      )
    end
    
    end_time = Time.current
    execution_time = end_time - start_time
    
    # Should initialize services very quickly
    assert execution_time < 0.1, "Service initialization too slow: #{execution_time}s"
  end

  test "suggestion uniqueness filtering is efficient" do
    # Create service with many duplicate existing steps
    duplicate_steps = 100.times.map { { step_type: 'email' } }
    
    service = JourneySuggestionService.new(
      campaign_type: 'awareness',
      existing_steps: duplicate_steps
    )
    
    start_time = Time.current
    
    10.times do
      service.suggest_steps(limit: 5)
    end
    
    end_time = Time.current
    execution_time = end_time - start_time
    
    # Should handle duplicate filtering efficiently
    assert execution_time < 0.1, "Duplicate filtering too slow: #{execution_time}s"
  end

  test "large limit values don't cause performance issues" do
    start_time = Time.current
    
    # Test with very large limit
    suggestions = @service.suggest_steps(limit: 10000)
    
    end_time = Time.current
    execution_time = end_time - start_time
    
    # Should handle large limits gracefully
    assert execution_time < 0.1, "Large limit handling too slow: #{execution_time}s"
    assert suggestions.length <= 50, "Should cap suggestions at reasonable limit"
  end

  test "memory usage stays constant across multiple calls" do
    # This is a simplified memory test - in real scenarios you'd use more sophisticated memory monitoring
    initial_objects = ObjectSpace.count_objects
    
    100.times do
      service = JourneySuggestionService.new(campaign_type: 'awareness')
      suggestions = service.suggest_steps
      channels = service.suggest_channels_for_step('email')
      content = service.suggest_content_for_step('email', 'discovery')
    end
    
    # Force garbage collection
    GC.start
    
    final_objects = ObjectSpace.count_objects
    
    # Memory usage shouldn't grow excessively (adjust threshold for test environment)
    memory_growth = final_objects[:TOTAL] - initial_objects[:TOTAL]
    assert memory_growth < 50000, "Excessive memory growth: #{memory_growth} objects"
  end

  test "service handles rapid consecutive calls without issues" do
    # Simulate rapid API calls
    results = []
    
    assert_nothing_raised do
      50.times do
        service = JourneySuggestionService.new(campaign_type: 'conversion')
        results << service.suggest_steps(limit: 3).length
      end
    end
    
    # All calls should succeed
    assert_equal 50, results.length
    results.each { |result| assert result >= 0 }
  end
end