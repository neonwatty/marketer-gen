require "test_helper"
require "benchmark"

class SimplifiedPerformanceTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @persona = create(:persona, user: @user)
  end

  test "basic campaign creation performance" do
    campaign_count = 50
    
    time = Benchmark.measure do
      campaign_count.times do |i|
        create(:campaign, 
          user: @user, 
          persona: @persona,
          name: "Performance Test Campaign #{i + 1}",
          goals: "Test campaign goals for performance testing"
        )
      end
    end
    
    campaigns_per_second = campaign_count / time.real
    puts "Created #{campaign_count} campaigns in #{time.real.round(2)} seconds"
    puts "Performance: #{campaigns_per_second.round(2)} campaigns/second"
    
    # Should create campaigns reasonably fast
    assert campaigns_per_second > 5, "Campaign creation too slow: #{campaigns_per_second.round(2)} campaigns/second"
    
    # Verify all campaigns were created
    assert_equal campaign_count, Campaign.count
  end

  test "campaign plan creation performance" do
    campaign = create(:campaign, user: @user, persona: @persona)
    
    plan_count = 10
    time = Benchmark.measure do
      plan_count.times do |i|
        create(:campaign_plan,
          campaign: campaign,
          user: @user,
          name: "Performance Plan #{i + 1}",
          strategic_rationale: "Test strategic rationale for performance testing",
          target_audience: "Test target audience",
          messaging_framework: "Test messaging framework",
          channel_strategy: "Test channel strategy",
          timeline_phases: "Test timeline phases",
          success_metrics: "Test success metrics"
        )
      end
    end
    
    plans_per_second = plan_count / time.real
    puts "Created #{plan_count} campaign plans in #{time.real.round(2)} seconds"
    puts "Performance: #{plans_per_second.round(2)} plans/second"
    
    # Should create plans reasonably fast
    assert plans_per_second > 1, "Campaign plan creation too slow: #{plans_per_second.round(2)} plans/second"
    
    # Verify all plans were created
    assert_equal plan_count, CampaignPlan.count
  end

  test "content repository creation performance" do
    content_count = 100
    
    time = Benchmark.measure do
      content_count.times do |i|
        create(:content_repository,
          title: "Performance Content #{i + 1}",
          body: "Test content body for performance testing",
          user: @user,
          content_type: 0,  # email_template
          format: 0,        # text format
          storage_path: "/test/content_#{i}",
          file_hash: "hash_#{i}"
        )
      end
    end
    
    content_per_second = content_count / time.real
    puts "Created #{content_count} content items in #{time.real.round(2)} seconds"
    puts "Performance: #{content_per_second.round(2)} items/second"
    
    # Should create content reasonably fast
    assert content_per_second > 10, "Content creation too slow: #{content_per_second.round(2)} items/second"
    
    # Verify all content was created
    assert_equal content_count, ContentRepository.count
  end

  test "A/B test creation performance" do
    campaign = create(:campaign, user: @user, persona: @persona)
    journey_a = create(:journey, user: @user, campaign: campaign, name: "Variant A")
    journey_b = create(:journey, user: @user, campaign: campaign, name: "Variant B")
    
    test_count = 20
    time = Benchmark.measure do
      test_count.times do |i|
        ab_test = create(:ab_test,
          name: "Performance Test #{i + 1}",
          description: "A/B test for performance evaluation",
          user: @user,
          campaign: campaign
        )
        
        create(:ab_test_variant, :control, ab_test: ab_test, journey: journey_a)
        create(:ab_test_variant, :variation, ab_test: ab_test, journey: journey_b)
      end
    end
    
    tests_per_second = test_count / time.real
    puts "Created #{test_count} A/B tests in #{time.real.round(2)} seconds"
    puts "Performance: #{tests_per_second.round(2)} tests/second"
    
    # Should create tests reasonably fast
    assert tests_per_second > 1, "A/B test creation too slow: #{tests_per_second.round(2)} tests/second"
    
    # Verify all tests were created
    assert_equal test_count, AbTest.count
    assert_equal test_count * 2, AbTestVariant.count
  end

  test "database query performance" do
    # Create test data
    campaigns = []
    10.times do |i|
      campaigns << create(:campaign, 
        user: @user, 
        persona: @persona,
        name: "Query Test Campaign #{i + 1}",
        status: ['draft', 'active', 'paused'].sample
      )
    end
    
    # Test simple queries
    query_time = Benchmark.measure do
      20.times do
        Campaign.where(user: @user).count
        Campaign.where(status: 'active').count
        Campaign.where("created_at > ?", 1.day.ago).count
      end
    end
    
    average_query_time = (query_time.real / 60) * 1000  # Convert to milliseconds
    puts "Average query time: #{average_query_time.round(2)}ms"
    
    # Should query quickly
    assert average_query_time < 50, "Database queries too slow: #{average_query_time.round(2)}ms average"
  end

  test "memory usage monitoring" do
    initial_memory = get_memory_usage
    
    # Create moderate amount of data
    50.times do |i|
      campaign = create(:campaign, user: @user, persona: @persona, name: "Memory Test #{i + 1}")
      create(:campaign_plan, campaign: campaign, user: @user, name: "Memory Plan #{i + 1}")
    end
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    puts "Memory increased by #{memory_increase.round(2)}MB during test operations"
    
    # Should not consume excessive memory
    assert memory_increase < 50, "Memory usage too high: #{memory_increase}MB"
  end

  private

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0
  end
end