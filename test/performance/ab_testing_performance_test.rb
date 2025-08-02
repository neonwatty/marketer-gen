require "test_helper"
require "benchmark"

class AbTestingPerformanceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @campaign = create(:campaign, user: @user)
    @journey_a = create(:journey, user: @user, campaign: @campaign, name: "Variant A Journey")
    @journey_b = create(:journey, user: @user, campaign: @campaign, name: "Variant B Journey")
  end

  test "A/B test creation with large-scale configuration" do
    test_count = 50
    
    time = Benchmark.measure do
      test_count.times do |i|
        ab_test = create(:ab_test,
          name: "Performance Test #{i + 1}",
          description: "Large-scale A/B test #{i + 1} for performance evaluation with complex configuration",
          user: @user,
          campaign: @campaign,
          test_type: ['messaging', 'visual', 'timing', 'targeting', 'content'].sample,
          hypothesis: "Performance test hypothesis #{i + 1} with detailed expected outcomes and success criteria",
          significance_level: [0.05, 0.01, 0.001].sample,
          minimum_sample_size: rand(1000..10000),
          max_duration_days: rand(7..30),
          traffic_allocation: {
            "total_percentage" => 100,
            "control_percentage" => 50,
            "variation_percentage" => 50
          },
          success_metrics: [
            { "name" => "conversion_rate", "type" => "rate", "target" => rand(5..25) },
            { "name" => "click_through_rate", "type" => "rate", "target" => rand(2..15) },
            { "name" => "engagement_score", "type" => "score", "target" => rand(60..90) }
          ]
        )
        
        # Create test variants
        create(:ab_test_variant, :control,
          ab_test: ab_test,
          journey: @journey_a,
          name: "Control Variant #{i + 1}",
          description: "Control variant for test #{i + 1}",
          traffic_percentage: 50.0,
          variant_config: {
            "messaging" => "Control messaging approach",
            "design_elements" => ["blue_cta", "header_v1", "layout_standard"],
            "personalization" => false,
            "timing_config" => { "delay" => 0, "frequency" => "standard" }
          }
        )
        
        create(:ab_test_variant, :variation,
          ab_test: ab_test,
          journey: @journey_b,
          name: "Variation Variant #{i + 1}",
          description: "Variation variant for test #{i + 1}",
          traffic_percentage: 50.0,
          variant_config: {
            "messaging" => "Experimental messaging approach",
            "design_elements" => ["green_cta", "header_v2", "layout_enhanced"],
            "personalization" => true,
            "timing_config" => { "delay" => 1800, "frequency" => "optimized" }
          }
        )
        
        # Create test configuration
        create(:ab_test_configuration,
          ab_test: ab_test,
          user: @user,
          config_type: 'advanced',
          traffic_rules: {
            "geographic_restrictions" => ["US", "CA", "UK"],
            "device_targeting" => ["desktop", "mobile"],
            "user_segments" => ["new_users", "returning_users"],
            "exclusion_rules" => ["bot_traffic", "internal_users"]
          },
          success_criteria: {
            "primary_metric" => "conversion_rate",
            "secondary_metrics" => ["engagement_score", "time_on_page"],
            "minimum_confidence" => 95,
            "minimum_effect_size" => 5.0
          },
          advanced_settings: {
            "sequential_testing" => true,
            "bayesian_analysis" => false,
            "early_stopping" => true,
            "power_analysis" => 0.8
          }
        )
      end
    end
    
    puts "Created #{test_count} A/B tests with variants and configurations in #{time.real.round(2)} seconds"
    puts "Average time per A/B test: #{(time.real / test_count * 1000).round(2)}ms"
    
    # Should create A/B tests efficiently (under 10 seconds for 50 tests)
    assert time.real < 10.0, "A/B test creation too slow: #{time.real} seconds"
    
    # Verify all tests were created
    assert_equal test_count, AbTest.count
    assert_equal test_count * 2, AbTestVariant.count  # 2 variants per test
    assert_equal test_count, AbTestConfiguration.count
  end

  test "large-scale visitor assignment performance" do
    ab_test = create(:ab_test, user: @user, campaign: @campaign)
    
    # Create test variants
    control_variant = create(:ab_test_variant, :control,
      ab_test: ab_test,
      journey: @journey_a,
      traffic_percentage: 50.0
    )
    
    variation_variant = create(:ab_test_variant, :variation,
      ab_test: ab_test,
      journey: @journey_b,
      traffic_percentage: 50.0
    )
    
    # Test large-scale visitor assignment
    visitor_count = 10000
    assignments = {}
    
    time = Benchmark.measure do
      visitor_count.times do |i|
        visitor_id = "visitor_#{i + 1}"
        assigned_variant = ab_test.assign_visitor(visitor_id)
        assignments[assigned_variant.id] ||= 0
        assignments[assigned_variant.id] += 1
        
        assert assigned_variant.present?
        assert [control_variant.id, variation_variant.id].include?(assigned_variant.id)
      end
    end
    
    control_count = assignments[control_variant.id] || 0
    variation_count = assignments[variation_variant.id] || 0
    
    puts "Assigned #{visitor_count} visitors in #{time.real.round(2)} seconds"
    puts "Control: #{control_count} visitors (#{(control_count.to_f / visitor_count * 100).round(2)}%)"
    puts "Variation: #{variation_count} visitors (#{(variation_count.to_f / visitor_count * 100).round(2)}%)"
    puts "Assignment rate: #{(visitor_count / time.real).round(2)} visitors/second"
    
    # Should assign visitors quickly (under 5 seconds for 10k visitors)
    assert time.real < 5.0, "Visitor assignment too slow: #{time.real} seconds"
    
    # Verify traffic split is approximately 50/50 (within 5% tolerance)
    split_difference = (control_count - variation_count).abs.to_f / visitor_count
    assert split_difference < 0.05, "Traffic split too uneven: #{split_difference * 100}% difference"
  end

  test "real-time metrics collection performance" do
    ab_test = create(:ab_test, user: @user, campaign: @campaign)
    control_variant = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey_a)
    variation_variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey_b)
    
    # Simulate large volume of metric events
    metrics_count = 5000
    metric_types = ['impression', 'click', 'conversion', 'engagement', 'bounce']
    
    time = Benchmark.measure do
      metrics_count.times do |i|
        variant = [control_variant, variation_variant].sample
        metric_type = metric_types.sample
        
        create(:ab_test_metric,
          ab_test: ab_test,
          ab_test_variant: variant,
          user: @user,
          metric_name: metric_type,
          metric_value: case metric_type
                       when 'impression' then 1
                       when 'click' then rand(0..1)
                       when 'conversion' then rand(0..1)
                       when 'engagement' then rand(1..100)
                       when 'bounce' then rand(0..1)
                       end,
          visitor_id: "visitor_#{rand(1..1000)}",
          session_id: "session_#{rand(1..2000)}",
          timestamp: Time.current - rand(7.days).seconds,
          metadata: {
            "page_url" => "/test-page-#{rand(1..10)}",
            "user_agent" => "Test User Agent #{i}",
            "referrer" => "https://example.com/ref#{rand(1..5)}",
            "device_type" => ["desktop", "mobile", "tablet"].sample,
            "location" => ["US", "CA", "UK", "AU"].sample
          }
        )
      end
    end
    
    puts "Collected #{metrics_count} real-time metrics in #{time.real.round(2)} seconds"
    puts "Metric collection rate: #{(metrics_count / time.real).round(2)} metrics/second"
    
    # Should collect metrics efficiently (under 8 seconds for 5k metrics)
    assert time.real < 8.0, "Metrics collection too slow: #{time.real} seconds"
    
    # Verify all metrics were recorded
    assert_equal metrics_count, AbTestMetric.count
  end

  test "statistical analysis performance with large datasets" do
    ab_test = create(:ab_test, 
      user: @user, 
      campaign: @campaign,
      significance_level: 0.05,
      minimum_sample_size: 1000
    )
    
    control_variant = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey_a)
    variation_variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey_b)
    
    # Create large dataset for statistical analysis
    sample_size = 2000
    
    # Generate realistic conversion data
    sample_size.times do |i|
      variant = [control_variant, variation_variant].sample
      
      # Control: 10% conversion rate, Variation: 12% conversion rate
      conversion_probability = variant == control_variant ? 0.10 : 0.12
      converted = rand < conversion_probability
      
      # Create impression metric
      create(:ab_test_metric,
        ab_test: ab_test,
        ab_test_variant: variant,
        user: @user,
        metric_name: 'impression',
        metric_value: 1,
        visitor_id: "analysis_visitor_#{i}",
        session_id: "analysis_session_#{i}",
        timestamp: Time.current - rand(7.days).seconds
      )
      
      # Create conversion metric if converted
      if converted
        create(:ab_test_metric,
          ab_test: ab_test,
          ab_test_variant: variant,
          user: @user,
          metric_name: 'conversion',
          metric_value: 1,
          visitor_id: "analysis_visitor_#{i}",
          session_id: "analysis_session_#{i}",
          timestamp: Time.current - rand(7.days).seconds
        )
      end
      
      # Add engagement metrics
      create(:ab_test_metric,
        ab_test: ab_test,
        ab_test_variant: variant,
        user: @user,
        metric_name: 'engagement',
        metric_value: rand(1..100),
        visitor_id: "analysis_visitor_#{i}",
        session_id: "analysis_session_#{i}",
        timestamp: Time.current - rand(7.days).seconds
      )
    end
    
    puts "Created statistical analysis dataset with #{sample_size} samples"
    
    # Test statistical analysis performance
    analysis_time = Benchmark.measure do
      # Run comprehensive statistical analysis
      analyzer = AbTestStatisticalAnalyzer.new(ab_test)
      
      # Basic statistics
      stats = analyzer.calculate_basic_statistics
      assert stats.present?
      
      # Significance testing
      significance_result = analyzer.calculate_significance
      assert significance_result.present?
      
      # Confidence intervals
      confidence_intervals = analyzer.calculate_confidence_intervals
      assert confidence_intervals.present?
      
      # Power analysis
      power_analysis = analyzer.calculate_power_analysis
      assert power_analysis.present?
      
      # Effect size calculation
      effect_size = analyzer.calculate_effect_size
      assert effect_size.present?
    end
    
    puts "Statistical analysis completed in #{analysis_time.real.round(2)} seconds"
    
    # Should complete analysis quickly (under 2 seconds)
    assert analysis_time.real < 2.0, "Statistical analysis too slow: #{analysis_time.real} seconds"
    
    # Test Bayesian analysis performance
    bayesian_time = Benchmark.measure do
      bayesian_analyzer = BayesianAbTestAnalyzer.new(ab_test)
      
      # Bayesian probability calculations
      bayesian_results = bayesian_analyzer.calculate_probabilities
      assert bayesian_results.present?
      
      # Credible intervals
      credible_intervals = bayesian_analyzer.calculate_credible_intervals
      assert credible_intervals.present?
      
      # Posterior distributions
      posteriors = bayesian_analyzer.sample_posteriors(1000)
      assert posteriors.present?
    end
    
    puts "Bayesian analysis completed in #{bayesian_time.real.round(2)} seconds"
    
    # Should complete Bayesian analysis quickly (under 3 seconds)
    assert bayesian_time.real < 3.0, "Bayesian analysis too slow: #{bayesian_time.real} seconds"
  end

  test "concurrent A/B test execution performance" do
    # Create multiple A/B tests for concurrent execution
    test_count = 10
    ab_tests = []
    
    test_count.times do |i|
      ab_test = create(:ab_test, 
        name: "Concurrent Test #{i + 1}",
        user: @user, 
        campaign: @campaign
      )
      
      create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey_a)
      create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey_b)
      
      ab_tests << ab_test
    end
    
    # Simulate concurrent traffic across all tests
    concurrent_visitors = 1000
    
    time = Benchmark.measure do
      threads = []
      
      # Create threads to simulate concurrent traffic
      10.times do |thread_idx|
        threads << Thread.new do
          (concurrent_visitors / 10).times do |visitor_idx|
            visitor_id = "concurrent_visitor_#{thread_idx}_#{visitor_idx}"
            
            # Each visitor participates in multiple tests
            ab_tests.sample(rand(1..3)).each do |test|
              assigned_variant = test.assign_visitor(visitor_id)
              
              # Generate metrics for this visitor
              create(:ab_test_metric,
                ab_test: test,
                ab_test_variant: assigned_variant,
                user: @user,
                metric_name: 'impression',
                metric_value: 1,
                visitor_id: visitor_id,
                session_id: "session_#{visitor_id}",
                timestamp: Time.current
              )
              
              # Random conversion
              if rand < 0.1  # 10% conversion rate
                create(:ab_test_metric,
                  ab_test: test,
                  ab_test_variant: assigned_variant,
                  user: @user,
                  metric_name: 'conversion',
                  metric_value: 1,
                  visitor_id: visitor_id,
                  session_id: "session_#{visitor_id}",
                  timestamp: Time.current
                )
              end
            end
          end
        end
      end
      
      # Wait for all threads to complete
      threads.each(&:join)
    end
    
    puts "Executed #{test_count} concurrent A/B tests with #{concurrent_visitors} visitors in #{time.real.round(2)} seconds"
    puts "Throughput: #{(concurrent_visitors / time.real).round(2)} visitors/second"
    
    # Should handle concurrent execution efficiently (under 15 seconds)
    assert time.real < 15.0, "Concurrent A/B test execution too slow: #{time.real} seconds"
    
    # Verify metrics were collected
    assert AbTestMetric.count > concurrent_visitors  # Should have at least impression metrics
  end

  test "A/B test results aggregation performance" do
    ab_test = create(:ab_test, user: @user, campaign: @campaign)
    control_variant = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey_a)
    variation_variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey_b)
    
    # Create extensive results dataset
    results_count = 100
    
    results_count.times do |i|
      variant = [control_variant, variation_variant].sample
      
      create(:ab_test_result,
        ab_test: ab_test,
        ab_test_variant: variant,
        user: @user,
        metric_name: 'conversion_rate',
        metric_value: rand(0.05..0.25),
        sample_size: rand(500..2000),
        confidence_level: 0.95,
        statistical_significance: rand > 0.5,
        p_value: rand(0.001..0.1),
        confidence_interval_lower: rand(0.03..0.15),
        confidence_interval_upper: rand(0.15..0.30),
        recorded_at: Time.current - rand(30.days).seconds,
        metadata: {
          "analysis_type" => ["frequentist", "bayesian"].sample,
          "effect_size" => rand(0.5..2.0),
          "power" => rand(0.7..0.95),
          "duration_days" => rand(1..30)
        }
      )
    end
    
    puts "Created #{results_count} A/B test results for aggregation testing"
    
    # Test results aggregation performance
    aggregation_time = Benchmark.measure do
      # Calculate summary statistics
      summary_stats = ab_test.calculate_summary_statistics
      assert summary_stats.present?
      
      # Generate performance trends
      performance_trends = ab_test.analyze_performance_trends(30)
      assert performance_trends.present?
      
      # Calculate win probability
      win_probability = ab_test.calculate_win_probability
      assert win_probability.present?
      
      # Generate comparison report
      comparison_report = ab_test.generate_comparison_report
      assert comparison_report.present?
      
      # Calculate cumulative results
      cumulative_results = ab_test.calculate_cumulative_results
      assert cumulative_results.present?
    end
    
    puts "Results aggregation completed in #{aggregation_time.real.round(2)} seconds"
    
    # Should aggregate results quickly (under 1 second)
    assert aggregation_time.real < 1.0, "Results aggregation too slow: #{aggregation_time.real} seconds"
  end

  test "memory usage during large A/B test operations" do
    initial_memory = get_memory_usage
    
    # Create comprehensive A/B test with large dataset
    ab_test = create(:ab_test, user: @user, campaign: @campaign)
    control_variant = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey_a)
    variation_variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey_b)
    
    # Create large metrics dataset
    1000.times do |i|
      variant = [control_variant, variation_variant].sample
      
      # Create multiple metric types per visitor
      ['impression', 'click', 'conversion', 'engagement'].each do |metric_type|
        create(:ab_test_metric,
          ab_test: ab_test,
          ab_test_variant: variant,
          user: @user,
          metric_name: metric_type,
          metric_value: rand(0..100),
          visitor_id: "memory_test_visitor_#{i}",
          session_id: "memory_test_session_#{i}",
          timestamp: Time.current - rand(7.days).seconds,
          metadata: {
            "detailed_tracking" => {
              "page_views" => Array.new(10) { |j| "page_#{j}" },
              "timestamps" => Array.new(10) { |j| (j + 1).minutes.ago },
              "scroll_depth" => Array.new(5) { rand(0..100) }
            }
          }
        )
      end
      
      # Create result records
      if i % 100 == 0  # Every 100th iteration
        create(:ab_test_result,
          ab_test: ab_test,
          ab_test_variant: variant,
          user: @user,
          metric_name: 'conversion_rate',
          metric_value: rand(0.05..0.25),
          sample_size: i + 1,
          confidence_level: 0.95,
          metadata: { "batch_number" => i / 100 }
        )
      end
    end
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    puts "Memory increased by #{memory_increase.round(2)}MB during large A/B test operations"
    
    # Should not consume excessive memory (less than 250MB increase)
    assert memory_increase < 250, "Memory usage too high: #{memory_increase}MB"
  end

  private

  def get_memory_usage
    # Simple memory usage check (in MB)
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0 # Return 0 if memory check fails
  end
end