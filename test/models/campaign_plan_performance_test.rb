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

  private

  def get_memory_usage
    # Simple memory usage approximation
    # In a real environment, you might use more sophisticated memory profiling
    GC.stat[:heap_allocated_pages] * 16384  # Approximate bytes
  end
end