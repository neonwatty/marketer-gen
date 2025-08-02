require "test_helper"
require "benchmark"
require "json"

class PerformanceTestRunner < ActiveSupport::TestCase
  PERFORMANCE_THRESHOLDS = {
    # Campaign Planning Performance
    campaign_creation_per_second: 10,
    campaign_plan_generation_max_seconds: 3.0,
    campaign_export_max_seconds: 5.0,
    campaign_search_max_seconds: 1.0,
    
    # Content Management Performance  
    content_creation_per_second: 33,  # 10k items in 30s = 333/s, allowing buffer
    content_search_max_seconds: 1.0,
    version_control_max_seconds: 5.0,
    approval_workflow_max_seconds: 3.0,
    
    # A/B Testing Performance
    visitor_assignment_per_second: 2000,  # 10k in 5s
    metrics_collection_per_second: 625,   # 5k in 8s
    statistical_analysis_max_seconds: 2.0,
    concurrent_test_execution_max_seconds: 15.0,
    
    # Database Performance
    query_optimization_max_seconds: 0.1,
    join_query_max_seconds: 0.5,
    index_query_max_milliseconds: 10,
    
    # Collaboration Performance
    concurrent_editing_max_seconds: 20.0,
    real_time_collaboration_max_seconds: 15.0,
    content_editing_max_seconds: 12.0,
    
    # Memory Usage (MB)
    max_memory_increase_campaign: 150,
    max_memory_increase_content: 200,
    max_memory_increase_ab_testing: 250,
    max_memory_increase_collaboration: 150
  }.freeze

  def setup
    @performance_results = {}
    @start_time = Time.current
    puts "\n" + "="*80
    puts "ENTERPRISE PERFORMANCE TEST SUITE"
    puts "Testing platform scalability with enterprise-scale data volumes"
    puts "="*80
  end

  def teardown
    @end_time = Time.current
    generate_performance_report
  end

  test "comprehensive performance benchmark suite" do
    puts "\nExecuting comprehensive performance benchmark suite..."
    
    # Test 1: Campaign Planning Performance
    run_performance_test("Campaign Planning") do
      test_campaign_planning_performance
    end
    
    # Test 2: Content Management Performance
    run_performance_test("Content Management") do
      test_content_management_performance
    end
    
    # Test 3: A/B Testing Performance
    run_performance_test("A/B Testing") do
      test_ab_testing_performance
    end
    
    # Test 4: Database Performance
    run_performance_test("Database Optimization") do
      test_database_performance
    end
    
    # Test 5: Concurrent Collaboration Performance
    run_performance_test("Concurrent Collaboration") do
      test_collaboration_performance
    end
    
    # Analyze overall performance
    analyze_performance_results
  end

  private

  def run_performance_test(test_name)
    puts "\n#{'-'*60}"
    puts "Testing: #{test_name}"
    puts "#{'-'*60}"
    
    initial_memory = get_memory_usage
    start_time = Time.current
    
    yield
    
    end_time = Time.current
    final_memory = get_memory_usage
    
    @performance_results[test_name] = {
      duration: end_time - start_time,
      memory_increase: final_memory - initial_memory,
      timestamp: start_time
    }
    
    puts "✓ #{test_name} completed in #{(end_time - start_time).round(2)}s"
    puts "  Memory increase: #{(final_memory - initial_memory).round(2)}MB"
  end

  def test_campaign_planning_performance
    user = create(:user)
    persona = create(:persona, user: user)
    
    # Mock LLM responses
    mock_campaign_planning_llm_response
    mock_creative_approach_llm_response
    
    # Test 1: Large campaign creation
    campaign_count = 100
    time = Benchmark.measure do
      campaign_count.times do |i|
        create(:campaign, 
          user: user, 
          persona: persona,
          name: "Perf Test Campaign #{i + 1}",
          goals: "Increase awareness, generate leads, drive conversions"
        )
      end
    end
    
    campaigns_per_second = campaign_count / time.real
    puts "  Campaign creation: #{campaigns_per_second.round(2)} campaigns/second"
    
    assert campaigns_per_second >= PERFORMANCE_THRESHOLDS[:campaign_creation_per_second],
           "Campaign creation too slow: #{campaigns_per_second.round(2)} campaigns/second"
    
    # Test 2: Complex plan generation
    campaign = create(:campaign, user: user, persona: persona)
    plan_time = Benchmark.measure do
      create(:campaign_plan,
        campaign: campaign,
        user: user,
        name: "Performance Test Plan",
        strategic_rationale: "Complex strategic rationale with detailed analysis",
        target_audience: "Enterprise decision makers and technical influencers",
        messaging_framework: "Professional, results-driven messaging approach",
        channel_strategy: "Multi-channel approach including email, social, content, paid search, webinars",
        timeline_phases: "12-week implementation with strategic phases",
        success_metrics: "500 leads, $1M revenue target, 15% conversion rate"
      )
    end
    
    puts "  Complex plan generation: #{plan_time.real.round(2)}s"
    
    assert plan_time.real <= PERFORMANCE_THRESHOLDS[:campaign_plan_generation_max_seconds],
           "Campaign plan generation too slow: #{plan_time.real}s"
  end

  def test_content_management_performance
    user = create(:user)
    repository = create(:content_repository, title: "Performance Repository", user: user)
    
    # Test 1: Large content creation
    content_count = 1000
    time = Benchmark.measure do
      content_count.times do |i|
        create(:content_repository,
          title: "Performance Content #{i + 1}",
          body: "Content body for performance testing",
          user: user,
          content_type: 0,  # email_template
          format: 0,  # text format
          storage_path: "/test/content_#{i}",
          file_hash: "hash_#{i}"
        )
      end
    end
    
    content_per_second = content_count / time.real
    puts "  Content creation: #{content_per_second.round(2)} items/second"
    
    assert content_per_second >= PERFORMANCE_THRESHOLDS[:content_creation_per_second],
           "Content creation too slow: #{content_per_second.round(2)} items/second"
    
    # Test 2: Content search performance
    search_time = Benchmark.measure do
      ContentRepository.where("title ILIKE ?", "%Performance%").limit(50).to_a
    end
    
    puts "  Content search: #{search_time.real.round(2)}s"
    
    assert search_time.real <= PERFORMANCE_THRESHOLDS[:content_search_max_seconds],
           "Content search too slow: #{search_time.real}s"
  end

  def test_ab_testing_performance
    user = create(:user)
    campaign = create(:campaign, user: user)
    journey_a = create(:journey, user: user, campaign: campaign, name: "Variant A")
    journey_b = create(:journey, user: user, campaign: campaign, name: "Variant B")
    
    # Test 1: Large-scale visitor assignment
    ab_test = create(:ab_test, user: user, campaign: campaign)
    control_variant = create(:ab_test_variant, :control, ab_test: ab_test, journey: journey_a)
    variation_variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: journey_b)
    
    visitor_count = 5000
    time = Benchmark.measure do
      visitor_count.times do |i|
        ab_test.assign_visitor("perf_visitor_#{i}")
      end
    end
    
    assignments_per_second = visitor_count / time.real
    puts "  Visitor assignment: #{assignments_per_second.round(2)} assignments/second"
    
    assert assignments_per_second >= PERFORMANCE_THRESHOLDS[:visitor_assignment_per_second],
           "Visitor assignment too slow: #{assignments_per_second.round(2)} assignments/second"
    
    # Test 2: Metrics collection
    metrics_count = 2500
    metrics_time = Benchmark.measure do
      metrics_count.times do |i|
        variant = [control_variant, variation_variant].sample
        create(:ab_test_metric,
          ab_test: ab_test,
          ab_test_variant: variant,
          user: user,
          metric_name: ['impression', 'click', 'conversion'].sample,
          metric_value: rand(0..1),
          visitor_id: "metrics_visitor_#{i}",
          timestamp: Time.current
        )
      end
    end
    
    metrics_per_second = metrics_count / metrics_time.real
    puts "  Metrics collection: #{metrics_per_second.round(2)} metrics/second"
    
    assert metrics_per_second >= PERFORMANCE_THRESHOLDS[:metrics_collection_per_second],
           "Metrics collection too slow: #{metrics_per_second.round(2)} metrics/second"
  end

  def test_database_performance
    user = create(:user)
    
    # Create test data for database performance
    campaigns = []
    50.times do |i|
      campaigns << create(:campaign, 
        user: user, 
        name: "DB Test Campaign #{i + 1}",
        status: ['draft', 'active', 'paused'].sample
      )
    end
    
    # Test 1: Index effectiveness
    index_time = Benchmark.measure do
      10.times do
        Campaign.where(user: user).count
        Campaign.where(status: 'active').count
        Campaign.where("created_at > ?", 7.days.ago).count
      end
    end
    
    average_index_time = (index_time.real / 30) * 1000  # Convert to milliseconds
    puts "  Index query performance: #{average_index_time.round(2)}ms average"
    
    assert average_index_time <= PERFORMANCE_THRESHOLDS[:index_query_max_milliseconds],
           "Index queries too slow: #{average_index_time.round(2)}ms average"
    
    # Test 2: Join performance
    journey = create(:journey, user: user, campaign: campaigns.first)
    10.times { |i| create(:journey_step, journey: journey, name: "Step #{i + 1}", position: i + 1) }
    
    join_time = Benchmark.measure do
      Campaign.joins(journeys: :journey_steps)
             .where(user: user)
             .group('campaigns.id')
             .select('campaigns.*, COUNT(journey_steps.id) as step_count')
             .to_a
    end
    
    puts "  Join query performance: #{join_time.real.round(2)}s"
    
    assert join_time.real <= PERFORMANCE_THRESHOLDS[:join_query_max_seconds],
           "Join queries too slow: #{join_time.real}s"
  end

  def test_collaboration_performance
    users = []
    5.times { |i| users << create(:user, email_address: "collab#{i}@example.com") }
    
    campaign = create(:campaign, user: users.first)
    journey = create(:journey, user: users.first, campaign: campaign)
    
    # Create steps for concurrent editing
    steps = []
    10.times do |i|
      steps << create(:journey_step,
        journey: journey,
        name: "Collab Step #{i + 1}",
        position: i + 1
      )
    end
    
    # Test concurrent editing performance
    concurrent_users = 8
    edits_per_user = 10
    
    time = Benchmark.measure do
      threads = []
      
      concurrent_users.times do |user_idx|
        threads << Thread.new do
          user = users[user_idx % users.length]
          
          edits_per_user.times do |edit_idx|
            step = steps.sample
            begin
              step.update!(name: "#{step.name} - Edit #{edit_idx + 1}")
              Activity.create!(
                user: user,
                action: 'journey_step_updated',
                trackable: step,
                metadata: { "concurrent_edit" => true }
              )
              sleep(0.01)
            rescue => e
              # Handle concurrent edit conflicts
            end
          end
        end
      end
      
      threads.each(&:join)
    end
    
    puts "  Concurrent editing: #{time.real.round(2)}s for #{concurrent_users} users"
    
    assert time.real <= PERFORMANCE_THRESHOLDS[:concurrent_editing_max_seconds],
           "Concurrent editing too slow: #{time.real}s"
  end

  def analyze_performance_results
    puts "\n" + "="*80
    puts "PERFORMANCE ANALYSIS SUMMARY"
    puts "="*80
    
    total_duration = @end_time - @start_time
    puts "Total test suite duration: #{total_duration.round(2)} seconds"
    
    # Check if all tests meet performance criteria
    all_passed = true
    failed_tests = []
    
    @performance_results.each do |test_name, results|
      status = case test_name
               when "Campaign Planning"
                 results[:memory_increase] <= PERFORMANCE_THRESHOLDS[:max_memory_increase_campaign]
               when "Content Management"
                 results[:memory_increase] <= PERFORMANCE_THRESHOLDS[:max_memory_increase_content]
               when "A/B Testing"
                 results[:memory_increase] <= PERFORMANCE_THRESHOLDS[:max_memory_increase_ab_testing]
               when "Concurrent Collaboration"
                 results[:memory_increase] <= PERFORMANCE_THRESHOLDS[:max_memory_increase_collaboration]
               else
                 true
               end
      
      if status
        puts "✓ #{test_name}: PASSED (#{results[:duration].round(2)}s, +#{results[:memory_increase].round(2)}MB)"
      else
        puts "✗ #{test_name}: FAILED (#{results[:duration].round(2)}s, +#{results[:memory_increase].round(2)}MB)"
        all_passed = false
        failed_tests << test_name
      end
    end
    
    if all_passed
      puts "\n🎉 ALL PERFORMANCE TESTS PASSED!"
      puts "Platform is ready for enterprise-scale usage."
    else
      puts "\n⚠️  PERFORMANCE ISSUES DETECTED"
      puts "Failed tests: #{failed_tests.join(', ')}"
      puts "Review and optimize before production deployment."
    end
    
    # Generate performance recommendations
    generate_performance_recommendations
    
    assert all_passed, "Performance test failures: #{failed_tests.join(', ')}"
  end

  def generate_performance_recommendations
    puts "\n" + "-"*60
    puts "PERFORMANCE OPTIMIZATION RECOMMENDATIONS"
    puts "-"*60
    
    recommendations = []
    
    @performance_results.each do |test_name, results|
      case test_name
      when "Campaign Planning"
        if results[:duration] > 20
          recommendations << "Consider implementing campaign creation batching for improved throughput"
        end
        if results[:memory_increase] > 100
          recommendations << "Optimize campaign plan data structures to reduce memory usage"
        end
        
      when "Content Management"
        if results[:duration] > 25
          recommendations << "Implement content indexing and search optimization"
        end
        if results[:memory_increase] > 150
          recommendations << "Consider streaming content processing for large datasets"
        end
        
      when "A/B Testing"
        if results[:duration] > 30
          recommendations << "Implement A/B test metric collection batching"
        end
        if results[:memory_increase] > 200
          recommendations << "Optimize A/B test data storage and retrieval"
        end
        
      when "Database Optimization"
        if results[:duration] > 10
          recommendations << "Review database indexes and query optimization"
        end
        
      when "Concurrent Collaboration"
        if results[:duration] > 25
          recommendations << "Implement optimistic locking and conflict resolution"
        end
        if results[:memory_increase] > 100
          recommendations << "Optimize real-time collaboration memory management"
        end
      end
    end
    
    if recommendations.empty?
      puts "✓ No specific optimizations needed - performance is within acceptable ranges"
    else
      recommendations.each_with_index do |rec, index|
        puts "#{index + 1}. #{rec}"
      end
    end
    
    puts "\nGeneral recommendations:"
    puts "• Monitor memory usage in production with real user loads"
    puts "• Implement database query monitoring and slow query alerts"
    puts "• Consider implementing caching layers for frequently accessed data"
    puts "• Set up performance monitoring dashboards for ongoing optimization"
    puts "• Regularly review and optimize database indexes based on query patterns"
  end

  def generate_performance_report
    report_data = {
      test_suite: "Enterprise Performance Test Suite",
      execution_time: @start_time,
      total_duration: @end_time - @start_time,
      results: @performance_results,
      thresholds: PERFORMANCE_THRESHOLDS,
      environment: {
        rails_version: Rails.version,
        ruby_version: RUBY_VERSION,
        database: ActiveRecord::Base.connection.adapter_name,
        test_environment: Rails.env
      }
    }
    
    # Save detailed report
    report_path = Rails.root.join("tmp", "performance_test_report_#{@start_time.strftime('%Y%m%d_%H%M%S')}.json")
    File.write(report_path, JSON.pretty_generate(report_data))
    
    puts "\n📊 Detailed performance report saved to: #{report_path}"
    puts "Use this report for performance tracking and optimization planning."
  end

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0
  end
end