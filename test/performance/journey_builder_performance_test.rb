require "test_helper"
require "benchmark"

class JourneyBuilderPerformanceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @persona = create(:persona, user: @user)
    @campaign = create(:campaign, user: @user, persona: @persona)
  end

  test "journey creation performance with many steps" do
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Benchmark creating 100 journey steps
    time = Benchmark.measure do
      100.times do |i|
        create(:journey_step,
          journey: journey,
          name: "Step #{i + 1}",
          stage: %w[awareness consideration conversion retention advocacy].sample,
          position: i + 1
        )
      end
    end
    
    puts "Created 100 journey steps in #{time.real.round(2)} seconds"
    
    # Should complete in reasonable time (less than 5 seconds)
    assert time.real < 5.0, "Journey step creation took too long: #{time.real} seconds"
    
    # Verify all steps were created
    assert_equal 100, journey.journey_steps.count
  end

  test "analytics calculation performance" do
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Create large dataset of analytics
    analytics_data = []
    30.times do |day|
      analytics_data << {
        journey: journey,
        campaign: @campaign,
        user: @user,
        period_start: day.days.ago,
        period_end: (day - 1).days.ago,
        total_executions: rand(500..2000),
        completed_executions: rand(300..1500),
        abandoned_executions: rand(50..200),
        conversion_rate: rand(5.0..25.0),
        engagement_score: rand(60.0..95.0)
      }
    end
    
    time = Benchmark.measure do
      analytics_data.each do |attrs|
        create(:journey_analytics, attrs)
      end
    end
    
    puts "Created 30 analytics records in #{time.real.round(2)} seconds"
    
    # Test analytics aggregation performance
    aggregation_time = Benchmark.measure do
      summary = journey.analytics_summary(30)
      trends = journey.performance_trends(7)
    end
    
    puts "Analytics aggregation took #{aggregation_time.real.round(2)} seconds"
    
    # Should complete aggregation quickly
    assert aggregation_time.real < 1.0, "Analytics aggregation too slow: #{aggregation_time.real} seconds"
  end

  test "journey suggestion engine performance" do
    # Skip if no API key available
    skip "No LLM API configured" unless Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY']
    
    journey = create(:journey, user: @user, campaign: @campaign)
    step = create(:journey_step, journey: journey)
    
    # Mock the API response to avoid actual API calls
    mock_llm_response(
      JSON.generate({
        suggestions: Array.new(10) do |i|
          {
            name: "Suggestion #{i + 1}",
            description: "Generated suggestion #{i + 1}",
            stage: %w[awareness consideration conversion].sample,
            content_type: "email",
            channel: "email",
            confidence_score: rand(0.6..0.95)
          }
        end
      })
    )
    
    engine = JourneySuggestionEngine.new(
      journey: journey,
      user: @user,
      current_step: step,
      provider: :openai
    )
    
    time = Benchmark.measure do
      10.times do
        suggestions = engine.generate_suggestions
        assert suggestions.is_a?(Array)
      end
    end
    
    puts "Generated 10 suggestion sets in #{time.real.round(2)} seconds"
    
    # Should complete quickly with mocked responses
    assert time.real < 2.0, "Suggestion generation too slow: #{time.real} seconds"
  end

  test "large journey duplication performance" do
    # Create a complex journey with many steps and transitions
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Create 50 steps with various configurations
    steps = []
    50.times do |i|
      steps << create(:journey_step,
        journey: journey,
        name: "Complex Step #{i + 1}",
        stage: %w[awareness consideration conversion retention advocacy].sample,
        position: i + 1,
        config: {
          "template" => "template_#{i}",
          "delay" => "#{rand(1..24)} hours",
          "conditions" => {
            "user_segment" => "segment_#{rand(1..5)}",
            "previous_action" => "action_#{rand(1..10)}"
          }
        }
      )
    end
    
    # Create step transitions
    20.times do
      from_step = steps.sample
      to_step = steps.sample
      next if from_step == to_step
      
      create(:step_transition,
        from_step: from_step,
        to_step: to_step,
        condition_type: "always",
        condition_value: "true"
      )
    end
    
    time = Benchmark.measure do
      duplicate = journey.duplicate
      assert duplicate.persisted?
    end
    
    puts "Duplicated complex journey in #{time.real.round(2)} seconds"
    
    # Should complete duplication in reasonable time
    assert time.real < 3.0, "Journey duplication too slow: #{time.real} seconds"
  end

  test "concurrent journey execution simulation" do
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Create multiple steps
    5.times do |i|
      create(:journey_step,
        journey: journey,
        name: "Step #{i + 1}",
        stage: %w[awareness consideration conversion].sample,
        position: i + 1
      )
    end
    
    # Simulate concurrent executions
    execution_count = 100
    
    time = Benchmark.measure do
      execution_count.times do |i|
        create(:journey_execution,
          journey: journey,
          user: @user,
          status: %w[active completed abandoned].sample,
          started_at: rand(7.days).seconds.ago,
          metadata: {
            "execution_id" => "exec_#{i}",
            "user_segment" => "segment_#{rand(1..3)}"
          }
        )
      end
    end
    
    puts "Created #{execution_count} journey executions in #{time.real.round(2)} seconds"
    
    # Should handle concurrent executions efficiently
    assert time.real < 5.0, "Journey execution creation too slow: #{time.real} seconds"
    
    # Verify all executions were created
    assert_equal execution_count, journey.journey_executions.count
  end

  test "A/B test variant assignment performance" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)
    journey_a = create(:journey, user: @user, campaign: @campaign, name: "Variant A")
    journey_b = create(:journey, user: @user, campaign: @campaign, name: "Variant B")
    
    create(:ab_test_variant, :control, ab_test: ab_test, journey: journey_a, traffic_percentage: 50.0)
    create(:ab_test_variant, :variation, ab_test: ab_test, journey: journey_b, traffic_percentage: 50.0)
    
    # Test assigning 1000 unique visitors
    visitor_count = 1000
    
    time = Benchmark.measure do
      visitor_count.times do |i|
        visitor_id = "visitor_#{i}"
        assigned_variant = ab_test.assign_visitor(visitor_id)
        assert assigned_variant.present?
      end
    end
    
    puts "Assigned #{visitor_count} visitors to A/B test variants in #{time.real.round(2)} seconds"
    
    # Should assign visitors quickly
    assert time.real < 2.0, "A/B test assignment too slow: #{time.real} seconds"
  end

  test "conversion funnel calculation performance" do
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Create large funnel dataset
    funnel_data = {
      "steps" => [
        { "name" => "Email Sent", "count" => 10000, "conversion_rate" => 1.0 },
        { "name" => "Email Opened", "count" => 6500, "conversion_rate" => 0.65 },
        { "name" => "Link Clicked", "count" => 2600, "conversion_rate" => 0.4 },
        { "name" => "Landing Page Viewed", "count" => 2340, "conversion_rate" => 0.9 },
        { "name" => "Form Started", "count" => 936, "conversion_rate" => 0.4 },
        { "name" => "Form Submitted", "count" => 468, "conversion_rate" => 0.5 }
      ]
    }
    
    time = Benchmark.measure do
      10.times do
        create(:conversion_funnel,
          journey: journey,
          funnel_data: funnel_data,
          total_users: 10000,
          final_conversions: 468,
          overall_conversion_rate: 4.68
        )
      end
    end
    
    puts "Created 10 conversion funnels in #{time.real.round(2)} seconds"
    
    # Test funnel analysis performance
    analysis_time = Benchmark.measure do
      journey.conversion_funnels.each do |funnel|
        analysis = funnel.analyze_drop_off_points
        optimization = funnel.suggest_optimizations
      end
    end
    
    puts "Analyzed 10 funnels in #{analysis_time.real.round(2)} seconds"
    
    # Should analyze funnels quickly
    assert analysis_time.real < 1.0, "Funnel analysis too slow: #{analysis_time.real} seconds"
  end

  test "memory usage during large operations" do
    # Monitor memory usage during journey creation
    initial_memory = get_memory_usage
    
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Create large number of related objects
    100.times do |i|
      step = create(:journey_step, journey: journey, name: "Step #{i}", position: i)
      create(:journey_analytics,
        journey: journey,
        campaign: @campaign,
        user: @user,
        total_executions: rand(100..1000),
        completed_executions: rand(50..800),
        abandoned_executions: rand(10..100)
      )
    end
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    puts "Memory increased by #{memory_increase}MB during large operation"
    
    # Should not consume excessive memory (less than 100MB increase)
    assert memory_increase < 100, "Memory usage too high: #{memory_increase}MB"
  end

  private

  def get_memory_usage
    # Simple memory usage check (in MB)
    # This is a basic implementation - in production you might use more sophisticated tools
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0 # Return 0 if memory check fails
  end
end