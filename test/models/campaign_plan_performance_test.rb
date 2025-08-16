require "test_helper"

class CampaignPlanPerformanceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
  end

  test "should handle large number of campaign plans efficiently" do
    # Create a moderate number of campaign plans for testing
    plans_count = 50
    
    start_time = Time.current
    
    plans_count.times do |i|
      @user.campaign_plans.create!(
        name: "Performance Test Campaign #{i}",
        campaign_type: CampaignPlan::CAMPAIGN_TYPES.sample,
        objective: CampaignPlan::OBJECTIVES.sample,
        status: CampaignPlan::STATUSES.sample,
        description: "Performance test description #{i}" * 10, # Make it longer
        target_audience: "Target audience for campaign #{i}",
        metadata: { test_index: i, created_for: "performance_test" }
      )
    end
    
    creation_time = Time.current - start_time
    assert creation_time < 5.seconds, "Creating #{plans_count} plans took too long: #{creation_time}s"
    
    # Test query performance
    query_start = Time.current
    
    # Test various query patterns
    recent_plans = @user.campaign_plans.recent.limit(20)
    draft_plans = @user.campaign_plans.by_status("draft")
    product_launch_plans = @user.campaign_plans.by_campaign_type("product_launch")
    search_results = @user.campaign_plans.where("name LIKE ?", "%Test%").limit(10)
    
    # Execute queries
    recent_plans.to_a
    draft_plans.count
    product_launch_plans.count
    search_results.to_a
    
    query_time = Time.current - query_start
    assert query_time < 1.second, "Queries took too long: #{query_time}s"
  end

  test "should efficiently handle JSON serialization" do
    large_strategy = {
      phases: Array.new(20) { |i| "Phase #{i+1}" },
      channels: Array.new(15) { |i| "Channel #{i+1}" },
      tactics: Array.new(50) { |i| "Tactic #{i+1}" },
      budget_breakdown: Hash[(1..20).map { |i| ["category_#{i}", rand(1000..10000)] }]
    }
    
    large_timeline = Array.new(100) do |i|
      {
        week: i + 1,
        activity: "Activity #{i+1}",
        details: "Detailed description " * 20,
        resources: Array.new(5) { |j| "Resource #{j+1}" }
      }
    end
    
    large_assets = Array.new(200) { |i| "Asset #{i+1}: " + ("description " * 10) }
    
    start_time = Time.current
    
    plan = @user.campaign_plans.create!(
      name: "Large Data Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      generated_strategy: large_strategy,
      generated_timeline: large_timeline,
      generated_assets: large_assets,
      status: "completed"
    )
    
    creation_time = Time.current - start_time
    assert creation_time < 2.seconds, "Creating plan with large JSON took too long: #{creation_time}s"
    
    # Test retrieval performance
    retrieval_start = Time.current
    
    plan.reload
    strategy = plan.generated_strategy
    timeline = plan.generated_timeline
    assets = plan.generated_assets
    
    retrieval_time = Time.current - retrieval_start
    assert retrieval_time < 1.second, "Retrieving large JSON took too long: #{retrieval_time}s"
    
    # Verify data integrity
    assert_equal 20, strategy["phases"].length
    assert_equal 100, timeline.length
    assert_equal 200, assets.length
  end

  test "should handle concurrent plan generation efficiently" do
    skip "Skipping concurrent test in single-threaded test environment"
    
    # This test would be valuable in a multi-threaded environment
    # It would test:
    # - Multiple users generating plans simultaneously
    # - Database connection pooling efficiency
    # - Lock contention on status updates
    # - LLM service rate limiting
  end

  test "should efficiently calculate analytics for many plans" do
    # Create plans with various statuses and completion states
    statuses = %w[draft generating completed failed archived]
    campaign_types = CampaignPlan::CAMPAIGN_TYPES
    
    30.times do |i|
      plan = @user.campaign_plans.create!(
        name: "Analytics Test #{i}",
        campaign_type: campaign_types[i % campaign_types.length],
        objective: CampaignPlan::OBJECTIVES.sample,
        status: statuses[i % statuses.length]
      )
      
      # Add generated content to some plans
      if %w[completed].include?(plan.status)
        plan.update!(
          generated_summary: "Summary for plan #{i}",
          generated_strategy: { phases: ["Phase 1", "Phase 2"] },
          generated_timeline: [{ week: 1, activity: "Activity 1" }],
          generated_assets: ["Asset 1", "Asset 2"]
        )
      end
    end
    
    start_time = Time.current
    
    # Calculate various analytics
    total_plans = @user.campaign_plans.count
    completed_plans = @user.campaign_plans.completed.count
    draft_plans = @user.campaign_plans.by_status("draft").count
    
    # Test plan analytics for multiple plans
    @user.campaign_plans.completed.each do |plan|
      analytics = plan.plan_analytics
      assert analytics.is_a?(Hash)
      assert analytics.key?(:campaign_type)
      assert analytics.key?(:generation_progress)
    end
    
    analytics_time = Time.current - start_time
    assert analytics_time < 2.seconds, "Analytics calculation took too long: #{analytics_time}s"
  end

  test "should handle memory efficiently with large text content" do
    # Test with large text content in various fields
    large_description = "A" * 2000  # Max allowed
    large_audience = "B" * 1000     # Max allowed  
    large_budget = "C" * 1000       # Max allowed
    large_timeline_constraints = "D" * 1000  # Max allowed
    
    start_memory = get_memory_usage
    
    plans = []
    20.times do |i|
      plans << @user.campaign_plans.create!(
        name: "Memory Test #{i}",
        description: large_description,
        target_audience: large_audience,
        budget_constraints: large_budget,
        timeline_constraints: large_timeline_constraints,
        campaign_type: "product_launch",
        objective: "brand_awareness"
      )
    end
    
    end_memory = get_memory_usage
    memory_increase = end_memory - start_memory
    
    # Memory increase should be reasonable (less than 10MB for 20 plans)
    assert memory_increase < 10.megabytes, "Memory usage increased too much: #{memory_increase.to_f / 1.megabyte}MB"
    
    # Verify all plans are accessible
    assert_equal 20, plans.length
    plans.each do |plan|
      assert_equal large_description, plan.description
    end
  end

  # Strategic fields performance tests
  test "strategic field serialization performance with large data" do
    large_content_strategy = {
      themes: Array.new(100) { |i| "theme_#{i}" },
      messaging_pillars: Array.new(50) { |i| "pillar_#{i}" },
      detailed_approach: "x" * 10000,  # Large text content
      campaign_phases: Array.new(20) { |i| { phase: i, duration: "#{i} weeks", activities: Array.new(10) { |j| "Activity #{j}" } } }
    }
    
    large_creative_approach = {
      visual_elements: Array.new(50) { |i| { element: "Element_#{i}", specification: "x" * 500 } },
      style_guide: { colors: Array.new(20) { |i| "##{i.to_s.rjust(6, '0')}" }, fonts: Array.new(10) { |i| "Font_#{i}" } },
      tone_variations: "x" * 5000
    }
    
    large_strategic_rationale = {
      market_analysis: "x" * 8000,
      competitive_landscape: "x" * 6000,
      risk_assessment: Array.new(30) { |i| { risk: "Risk_#{i}", mitigation: "x" * 200 } },
      success_metrics: Array.new(25) { |i| { metric: "Metric_#{i}", target: "Target_#{i}" } }
    }
    
    large_content_mapping = Array.new(100) do |i|
      {
        platform: "Platform_#{i}",
        content_type: "Type_#{i}",
        frequency: "daily",
        details: "x" * 1000,
        publishing_schedule: Array.new(7) { |j| { day: j, time: "#{j+8}:00 AM", content: "x" * 200 } }
      }
    end
    
    campaign_plan = campaign_plans(:draft_plan)
    
    # Measure serialization performance
    start_time = Time.current
    campaign_plan.update!(
      content_strategy: large_content_strategy,
      creative_approach: large_creative_approach,
      strategic_rationale: large_strategic_rationale,
      content_mapping: large_content_mapping
    )
    serialization_time = Time.current - start_time
    
    # Should complete within reasonable time (adjust threshold as needed)
    assert serialization_time < 2.0, "Strategic field serialization took too long: #{serialization_time}s"
    
    # Test retrieval performance
    retrieval_start = Time.current
    campaign_plan.reload
    
    # Access all strategic fields
    strategy = campaign_plan.content_strategy
    approach = campaign_plan.creative_approach
    rationale = campaign_plan.strategic_rationale
    mapping = campaign_plan.content_mapping
    
    retrieval_time = Time.current - retrieval_start
    assert retrieval_time < 1.0, "Strategic field retrieval took too long: #{retrieval_time}s"
    
    # Verify data integrity after serialization
    assert_equal 100, strategy["themes"].length
    assert_equal 50, approach["visual_elements"].length
    assert_equal 30, rationale["risk_assessment"].length
    assert_equal 100, mapping.length
  end

  test "strategic field progress calculation performance with multiple plans" do
    # Create plans with various strategic field combinations
    plans = []
    50.times do |i|
      plan = @user.campaign_plans.create!(
        name: "Strategic Performance Test #{i}",
        campaign_type: CampaignPlan::CAMPAIGN_TYPES.sample,
        objective: CampaignPlan::OBJECTIVES.sample
      )
      
      # Add random combinations of strategic fields
      case i % 4
      when 0
        plan.update!(
          status: 'generating',
          content_strategy: { themes: ["theme_#{i}"] },
          creative_approach: { style: "style_#{i}" }
        )
      when 1
        plan.update!(
          status: 'generating',
          strategic_rationale: { reasoning: "reasoning_#{i}" },
          content_mapping: [{ platform: "platform_#{i}" }]
        )
      when 2
        plan.update!(
          status: 'generating',
          generated_summary: "Summary #{i}",
          content_strategy: { approach: "approach_#{i}" },
          creative_approach: { tone: "tone_#{i}" },
          strategic_rationale: { justification: "justification_#{i}" }
        )
      when 3
        plan.update!(
          status: 'completed',
          generated_summary: "Summary #{i}",
          generated_strategy: { phases: ["Phase #{i}"] },
          generated_timeline: [{ week: 1, activity: "Activity #{i}" }],
          generated_assets: ["Asset #{i}"],
          content_strategy: { themes: ["complete_#{i}"] },
          creative_approach: { style: "complete_#{i}" },
          strategic_rationale: { reasoning: "complete_#{i}" },
          content_mapping: [{ platform: "complete_#{i}" }]
        )
      end
      
      plans << plan
    end
    
    # Test generation progress calculation performance
    start_time = Time.current
    
    progress_results = plans.map do |plan|
      plan.reload
      {
        plan_id: plan.id,
        progress: plan.generation_progress,
        has_content: plan.has_generated_content?,
        analytics: plan.plan_analytics
      }
    end
    
    calculation_time = Time.current - start_time
    assert calculation_time < 2.0, "Progress calculation for 50 plans took too long: #{calculation_time}s"
    
    # Verify calculations are correct
    complete_plans = progress_results.select { |r| r[:progress] == 100 }
    assert complete_plans.length > 0, "Should have some complete plans"
    
    partial_plans = progress_results.select { |r| r[:progress] > 0 && r[:progress] < 100 }
    assert partial_plans.length > 0, "Should have some partial plans"
  end

  test "strategic field JSON processing performance with complex nested data" do
    # Test deeply nested strategic content
    complex_content_strategy = {
      primary_themes: {
        innovation: {
          sub_themes: Array.new(20) { |i| "innovation_#{i}" },
          messaging: {
            headlines: Array.new(30) { |i| "Headline #{i}" },
            body_copy: Array.new(20) { |i| "x" * 500 },
            call_to_actions: Array.new(15) { |i| "CTA #{i}" }
          }
        },
        trust: {
          sub_themes: Array.new(15) { |i| "trust_#{i}" },
          evidence_points: Array.new(25) { |i| { point: "Evidence #{i}", source: "Source #{i}" } }
        }
      },
      channel_strategies: {
        digital: {
          platforms: Array.new(10) do |i|
            {
              name: "Platform_#{i}",
              content_types: Array.new(5) { |j| "Type_#{j}" },
              posting_frequency: "daily",
              engagement_tactics: Array.new(8) { |k| "Tactic_#{k}" }
            }
          end
        }
      }
    }
    
    campaign_plan = campaign_plans(:draft_plan)
    
    # Test serialization of complex nested data
    start_time = Time.current
    campaign_plan.update!(content_strategy: complex_content_strategy)
    serialization_time = Time.current - start_time
    
    assert serialization_time < 1.0, "Complex nested serialization took too long: #{serialization_time}s"
    
    # Test access performance with nested data
    access_start = Time.current
    campaign_plan.reload
    
    # Access deeply nested elements
    innovation_themes = campaign_plan.content_strategy["primary_themes"]["innovation"]["sub_themes"]
    digital_platforms = campaign_plan.content_strategy["channel_strategies"]["digital"]["platforms"]
    headlines = campaign_plan.content_strategy["primary_themes"]["innovation"]["messaging"]["headlines"]
    
    access_time = Time.current - access_start
    assert access_time < 0.5, "Complex nested data access took too long: #{access_time}s"
    
    # Verify data integrity
    assert_equal 20, innovation_themes.length
    assert_equal 10, digital_platforms.length
    assert_equal 30, headlines.length
  end

  test "strategic field memory usage with concurrent operations" do
    initial_memory = get_memory_usage
    
    # Simulate concurrent operations on strategic fields
    plans = []
    threads = []
    
    # Create multiple plans with strategic content in parallel simulation
    5.times do |i|
      plan = @user.campaign_plans.create!(
        name: "Concurrent Test #{i}",
        campaign_type: "product_launch",
        objective: "brand_awareness"
      )
      plans << plan
    end
    
    # Update all plans with strategic content
    plans.each_with_index do |plan, i|
      large_strategy = {
        themes: Array.new(50) { |j| "theme_#{i}_#{j}" },
        detailed_content: "x" * 5000
      }
      
      large_mapping = Array.new(30) do |j|
        {
          platform: "Platform_#{i}_#{j}",
          content: "x" * 1000
        }
      end
      
      plan.update!(
        content_strategy: large_strategy,
        content_mapping: large_mapping
      )
    end
    
    # Perform operations on all plans
    start_time = Time.current
    
    plans.each do |plan|
      plan.reload
      analytics = plan.plan_analytics
      progress = plan.generation_progress
      content_check = plan.has_generated_content?
    end
    
    operation_time = Time.current - start_time
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    assert operation_time < 3.0, "Concurrent-style operations took too long: #{operation_time}s"
    assert memory_increase < 20.megabytes, "Memory usage increased too much: #{memory_increase.to_f / 1.megabyte}MB"
  end

  private

  def get_memory_usage
    # Simple memory usage approximation
    # In a real environment, you might use more sophisticated memory profiling
    GC.stat[:heap_allocated_pages] * 16384  # Approximate bytes
  end
end