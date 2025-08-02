require "test_helper"
require "benchmark"

class CampaignPlanningPerformanceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @brand = create(:brand, user: @user)
    @persona = create(:persona, user: @user)
    
    # Mock LLM responses to avoid API calls during performance testing
    mock_campaign_planning_llm_response
    mock_creative_approach_llm_response
  end

  # Test performance with large number of campaigns
  test "campaign generation performance with 100+ campaigns" do
    campaign_count = 100
    
    time = Benchmark.measure do
      campaign_count.times do |i|
        create(:campaign, 
          user: @user, 
          persona: @persona,
          name: "Performance Test Campaign #{i + 1}",
          description: "Campaign #{i + 1} for performance testing with detailed objectives and complex targeting",
          goals: "Increase brand awareness by #{rand(10..50)}%, generate #{rand(100..1000)} qualified leads, achieve #{rand(5..15)}% conversion rate"
        )
      end
    end
    
    puts "Created #{campaign_count} campaigns in #{time.real.round(2)} seconds"
    puts "Average time per campaign: #{(time.real / campaign_count * 1000).round(2)}ms"
    
    # Should create campaigns efficiently (under 10 seconds for 100 campaigns)
    assert time.real < 10.0, "Campaign creation too slow: #{time.real} seconds for #{campaign_count} campaigns"
    
    # Verify all campaigns were created
    assert_equal campaign_count, Campaign.count
  end

  test "campaign plan generation performance with complex data" do
    campaigns = []
    5.times do |i|
      campaigns << create(:campaign, 
        user: @user, 
        persona: @persona,
        name: "Complex Campaign #{i + 1}",
        goals: "Multi-channel awareness campaign, advanced segmentation strategy, personalized customer journey mapping"
      )
    end
    
    # Test campaign plan generation performance
    time = Benchmark.measure do
      campaigns.each do |campaign|
        plan = create(:campaign_plan,
          campaign: campaign,
          user: @user,
          strategic_rationale: "Complex strategic rationale with detailed market analysis and competitive positioning",
          target_audience: {
            "primary" => "Enterprise decision makers",
            "secondary" => "Technical influencers",
            "demographics" => {
              "age_range" => "30-55",
              "job_titles" => ["CTO", "VP Engineering", "Director of Technology"],
              "company_size" => "500-5000 employees",
              "industries" => ["Technology", "Financial Services", "Healthcare"]
            }
          },
          success_metrics: {
            "primary_kpis" => [
              { "metric" => "Lead Generation", "target" => 500, "weight" => 0.4 },
              { "metric" => "Pipeline Revenue", "target" => 2000000, "weight" => 0.3 },
              { "metric" => "Brand Awareness", "target" => 25, "weight" => 0.3 }
            ],
            "secondary_kpis" => [
              { "metric" => "Email Engagement", "target" => 15 },
              { "metric" => "Website Traffic", "target" => 50000 },
              { "metric" => "Social Reach", "target" => 1000000 }
            ]
          },
          timeline: {
            "total_duration" => "12 weeks",
            "phases" => [
              { "name" => "Research & Planning", "duration" => "2 weeks", "start_week" => 1 },
              { "name" => "Content Creation", "duration" => "3 weeks", "start_week" => 3 },
              { "name" => "Campaign Launch", "duration" => "1 week", "start_week" => 6 },
              { "name" => "Optimization", "duration" => "4 weeks", "start_week" => 7 },
              { "name" => "Analysis & Reporting", "duration" => "2 weeks", "start_week" => 11 }
            ]
          },
          channels: {
            "digital" => ["email", "social_media", "content_marketing", "paid_search", "display_ads"],
            "traditional" => ["webinars", "conferences", "direct_mail"],
            "channel_mix" => {
              "email" => { "budget_percentage" => 25, "expected_reach" => 50000 },
              "social_media" => { "budget_percentage" => 20, "expected_reach" => 100000 },
              "content_marketing" => { "budget_percentage" => 30, "expected_reach" => 75000 },
              "paid_search" => { "budget_percentage" => 15, "expected_reach" => 25000 },
              "display_ads" => { "budget_percentage" => 10, "expected_reach" => 200000 }
            }
          }
        )
        
        # Create associated plan revisions
        3.times do |rev|
          create(:plan_revision,
            campaign_plan: plan,
            user: @user,
            version_number: rev + 1,
            changes_summary: "Revision #{rev + 1} with strategic updates and optimizations",
            revision_notes: "Updated targeting criteria and budget allocation based on performance data"
          )
        end
        
        # Create plan comments
        5.times do |comment_idx|
          create(:plan_comment,
            campaign_plan: plan,
            user: @user,
            comment_text: "Strategic feedback #{comment_idx + 1} on campaign approach and execution",
            section: ["strategic_rationale", "target_audience", "success_metrics", "timeline", "channels"].sample
          )
        end
      end
    end
    
    puts "Generated 5 complex campaign plans with revisions and comments in #{time.real.round(2)} seconds"
    puts "Average time per complex plan: #{(time.real / 5 * 1000).round(2)}ms"
    
    # Should generate complex plans efficiently (under 3 seconds)
    assert time.real < 3.0, "Complex campaign plan generation too slow: #{time.real} seconds"
    
    # Verify data integrity
    assert_equal 5, CampaignPlan.count
    assert_equal 15, PlanRevision.count  # 3 revisions per plan
    assert_equal 25, PlanComment.count   # 5 comments per plan
  end

  test "campaign export performance with large datasets" do
    # Create campaign with extensive data
    campaign = create(:campaign, user: @user, persona: @persona)
    plan = create(:campaign_plan, campaign: campaign, user: @user)
    
    # Create large associated dataset
    50.times { |i| create(:plan_revision, campaign_plan: plan, user: @user, version_number: i + 1) }
    100.times { create(:plan_comment, campaign_plan: plan, user: @user) }
    
    # Create extensive journey data
    journey = create(:journey, user: @user, campaign: campaign)
    25.times do |i|
      step = create(:journey_step, journey: journey, name: "Export Test Step #{i}", position: i + 1)
      create(:journey_analytics, journey: journey, campaign: campaign, user: @user)
    end
    
    # Test PDF export performance
    pdf_time = Benchmark.measure do
      exporter = CampaignPlanExporter.new(plan)
      pdf_content = exporter.export_to_pdf
      assert pdf_content.present?
    end
    
    puts "PDF export with large dataset completed in #{pdf_time.real.round(2)} seconds"
    
    # Should export to PDF quickly (under 5 seconds)
    assert pdf_time.real < 5.0, "PDF export too slow: #{pdf_time.real} seconds"
    
    # Test PowerPoint export performance  
    pptx_time = Benchmark.measure do
      exporter = CampaignPlanExporter.new(plan)
      pptx_content = exporter.export_to_powerpoint
      assert pptx_content.present?
    end
    
    puts "PowerPoint export with large dataset completed in #{pptx_time.real.round(2)} seconds"
    
    # Should export to PowerPoint quickly (under 7 seconds)
    assert pptx_time.real < 7.0, "PowerPoint export too slow: #{pptx_time.real} seconds"
  end

  test "campaign search and filtering performance" do
    # Create large dataset of campaigns with varied attributes
    campaigns = []
    200.times do |i|
      campaigns << create(:campaign,
        user: @user,
        persona: @persona,
        name: "Search Test Campaign #{i + 1}",
        description: "Campaign for search performance testing with keywords: #{['technology', 'innovation', 'growth', 'strategy', 'marketing'].sample(3).join(' ')}",
        status: ['draft', 'active', 'paused', 'completed'].sample,
        budget: rand(1000..100000),
        start_date: Date.current - rand(365).days,
        end_date: Date.current + rand(365).days,
        goals: "Objective #{i % 10 + 1}, Goal #{i % 5 + 1}, Target #{i % 7 + 1}"
      )
    end
    
    # Test various search and filter operations
    search_time = Benchmark.measure do
      # Text search
      results = Campaign.where("name ILIKE ? OR description ILIKE ?", "%technology%", "%technology%")
      assert results.count > 0
      
      # Status filtering
      active_campaigns = Campaign.where(status: 'active')
      assert active_campaigns.count >= 0
      
      # Budget range filtering
      high_budget = Campaign.where("budget > ?", 50000)
      assert high_budget.count >= 0
      
      # Date range filtering
      recent_campaigns = Campaign.where("start_date > ?", 30.days.ago)
      assert recent_campaigns.count >= 0
      
      # Complex combined filtering
      complex_results = Campaign.where(status: ['active', 'draft'])
                               .where("budget BETWEEN ? AND ?", 5000, 75000)
                               .where("start_date > ?", 90.days.ago)
      assert complex_results.count >= 0
    end
    
    puts "Campaign search and filtering (200 campaigns) completed in #{search_time.real.round(2)} seconds"
    
    # Should search and filter quickly (under 1 second)
    assert search_time.real < 1.0, "Campaign search too slow: #{search_time.real} seconds"
  end

  test "campaign analytics aggregation performance" do
    campaigns = []
    5.times do |i|
      campaigns << create(:campaign, user: @user, persona: @persona, name: "Analytics Test #{i + 1}")
    end
    
    # Create large analytics dataset
    analytics_data = []
    campaigns.each do |campaign|
      journey = create(:journey, user: @user, campaign: campaign)
      
      # Create 90 days of analytics data
      90.times do |day|
        analytics_data << create(:journey_analytics,
          journey: journey,
          campaign: campaign,
          user: @user,
          period_start: day.days.ago.beginning_of_day,
          period_end: day.days.ago.end_of_day,
          total_executions: rand(100..1000),
          completed_executions: rand(50..800),
          abandoned_executions: rand(10..200),
          conversion_rate: rand(1.0..15.0),
          engagement_score: rand(40.0..95.0)
        )
      end
    end
    
    puts "Created #{analytics_data.length} analytics records for aggregation testing"
    
    # Test analytics aggregation performance
    aggregation_time = Benchmark.measure do
      campaigns.each do |campaign|
        # Monthly summaries
        monthly_summary = campaign.analytics_summary(30)
        assert monthly_summary.present?
        
        # Weekly trends
        weekly_trends = campaign.performance_trends(7)
        assert weekly_trends.present?
        
        # Quarterly analysis
        quarterly_analysis = campaign.analytics_summary(90)
        assert quarterly_analysis.present?
        
        # Performance comparisons
        comparison_data = campaign.compare_periods(30, 60)
        assert comparison_data.present?
      end
    end
    
    puts "Analytics aggregation for 5 campaigns (450 records) completed in #{aggregation_time.real.round(2)} seconds"
    
    # Should aggregate analytics quickly (under 2 seconds)
    assert aggregation_time.real < 2.0, "Analytics aggregation too slow: #{aggregation_time.real} seconds"
  end

  test "concurrent campaign planning simulation" do
    # Simulate multiple users creating campaigns simultaneously
    user_count = 10
    campaigns_per_user = 5
    
    time = Benchmark.measure do
      threads = []
      
      user_count.times do |user_idx|
        threads << Thread.new do
          test_user = create(:user, email_address: "perftest#{user_idx}@example.com")
          test_persona = create(:persona, user: test_user)
          
          campaigns_per_user.times do |campaign_idx|
            create(:campaign,
              user: test_user,
              persona: test_persona,
              name: "Concurrent Test Campaign U#{user_idx}-C#{campaign_idx}",
              description: "Campaign created by user #{user_idx}, campaign #{campaign_idx}"
            )
          end
        end
      end
      
      # Wait for all threads to complete
      threads.each(&:join)
    end
    
    total_campaigns = user_count * campaigns_per_user
    puts "Created #{total_campaigns} campaigns concurrently (#{user_count} users) in #{time.real.round(2)} seconds"
    puts "Throughput: #{(total_campaigns / time.real).round(2)} campaigns/second"
    
    # Should handle concurrent creation efficiently (under 15 seconds)
    assert time.real < 15.0, "Concurrent campaign creation too slow: #{time.real} seconds"
    
    # Verify all campaigns were created
    assert Campaign.count >= total_campaigns
  end

  test "memory usage during large campaign operations" do
    initial_memory = get_memory_usage
    
    # Create large campaign with extensive related data
    campaign = create(:campaign, user: @user, persona: @persona)
    plan = create(:campaign_plan, campaign: campaign, user: @user)
    
    # Create large associated dataset
    100.times do |i|
      create(:plan_revision, 
        campaign_plan: plan, 
        user: @user, 
        version_number: i + 1,
        changes_summary: "Performance test revision #{i + 1} with detailed changes and strategic updates"
      )
    end
    
    200.times do |i|
      create(:plan_comment,
        campaign_plan: plan,
        user: @user,
        comment_text: "Performance test comment #{i + 1} with detailed feedback and strategic recommendations"
      )
    end
    
    # Create extensive journey and analytics data
    journey = create(:journey, user: @user, campaign: campaign)
    50.times do |i|
      step = create(:journey_step, journey: journey, name: "Memory Test Step #{i}", position: i + 1)
      create(:journey_analytics, journey: journey, campaign: campaign, user: @user)
    end
    
    final_memory = get_memory_usage
    memory_increase = final_memory - initial_memory
    
    puts "Memory increased by #{memory_increase.round(2)}MB during large campaign operations"
    
    # Should not consume excessive memory (less than 150MB increase)
    assert memory_increase < 150, "Memory usage too high: #{memory_increase}MB"
  end

  private

  def get_memory_usage
    # Simple memory usage check (in MB)
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0 # Return 0 if memory check fails
  end
end