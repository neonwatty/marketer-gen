require "test_helper"

class CompetitiveAnalysisWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
  end

  test "complete competitive analysis integration workflow" do
    # Step 1: Verify initial state
    assert_not @campaign_plan.has_competitive_data?
    assert @campaign_plan.competitive_analysis_stale?
    assert_nil @campaign_plan.competitive_analysis_last_updated_at
    
    # Step 2: Initiate competitive analysis
    service = CompetitiveAnalysisService.new(@campaign_plan)
    
    # Mock LLM responses for complete workflow
    mock_successful_llm_responses do
      # Step 3: Process analysis in background job
      assert_performed_jobs 1, only: CompetitiveAnalysisJob do
        result = service.call
        assert result[:success]
      end
      
      # Step 4: Execute the background job
      perform_enqueued_jobs only: CompetitiveAnalysisJob
    end
    
    # Step 5: Verify final state
    @campaign_plan.reload
    
    assert @campaign_plan.has_competitive_data?
    assert_not @campaign_plan.competitive_analysis_stale?
    assert_not_nil @campaign_plan.competitive_analysis_last_updated_at
    
    # Step 6: Verify all competitive data was populated
    verify_competitive_intelligence_data
    verify_market_research_data
    verify_competitor_analysis_data
    verify_industry_benchmarks_data
    
    # Step 7: Test competitive analysis helper methods
    verify_helper_methods_functionality
  end

  test "competitive analysis workflow handles service failures gracefully" do
    # Mock LLM service to fail
    mock_failed_llm_responses do
      service = CompetitiveAnalysisService.new(@campaign_plan)
      
      # Should still succeed with default data
      result = service.perform_analysis
      assert result[:success]
      
      @campaign_plan.reload
      
      # Should have default competitive data
      assert @campaign_plan.has_competitive_data?
      
      # Verify default data is present
      competitive_data = @campaign_plan.parsed_competitive_intelligence
      assert_includes competitive_data['competitive_advantages'], 'Market experience'
      assert_includes competitive_data['market_threats'], 'New competitors'
    end
  end

  test "competitive analysis refresh workflow" do
    # Step 1: Set up stale competitive analysis data
    @campaign_plan.update!(
      competitive_intelligence: { "old_data" => "stale" },
      competitive_analysis_last_updated_at: 10.days.ago
    )
    
    assert @campaign_plan.competitive_analysis_stale?
    
    # Step 2: Refresh competitive analysis
    mock_successful_llm_responses do
      result = @campaign_plan.refresh_competitive_analysis!
      assert result
      
      perform_enqueued_jobs only: CompetitiveAnalysisJob
    end
    
    # Step 3: Verify data was refreshed
    @campaign_plan.reload
    
    assert_not @campaign_plan.competitive_analysis_stale?
    competitive_data = @campaign_plan.parsed_competitive_intelligence
    assert_not_equal({ "old_data" => "stale" }, competitive_data)
  end

  test "competitive analysis scopes work correctly" do
    # Create test data
    plan_with_data = CampaignPlan.create!(
      user: @user,
      name: "Plan with Competitive Data",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      competitive_intelligence: { "data" => "present" }
    )
    
    plan_without_data = CampaignPlan.create!(
      user: @user,
      name: "Plan without Competitive Data",
      campaign_type: "lead_generation", 
      objective: "customer_acquisition"
    )
    
    stale_plan = CampaignPlan.create!(
      user: @user,
      name: "Stale Plan",
      campaign_type: "brand_awareness",
      objective: "customer_retention",
      competitive_intelligence: { "data" => "old" },
      competitive_analysis_last_updated_at: 10.days.ago
    )
    
    never_analyzed_plan = CampaignPlan.create!(
      user: @user,
      name: "Never Analyzed Plan", 
      campaign_type: "sales_promotion",
      objective: "sales_growth",
      competitive_analysis_last_updated_at: nil
    )
    
    # Test scopes
    plans_with_data = CampaignPlan.with_competitive_analysis
    assert_includes plans_with_data, plan_with_data
    assert_includes plans_with_data, stale_plan
    assert_not_includes plans_with_data, plan_without_data
    assert_not_includes plans_with_data, never_analyzed_plan
    
    stale_plans = CampaignPlan.competitive_analysis_stale
    assert_includes stale_plans, stale_plan
    assert_includes stale_plans, never_analyzed_plan
    assert_not_includes stale_plans, plan_with_data
    
    needs_analysis = CampaignPlan.needs_competitive_analysis
    assert_includes needs_analysis, never_analyzed_plan
    assert_not_includes needs_analysis, stale_plan
    assert_not_includes needs_analysis, plan_with_data
  end

  test "competitive analysis data extraction and parsing" do
    # Set up complex competitive data
    setup_comprehensive_competitive_data
    
    @campaign_plan.reload
    
    # Test top competitors extraction
    top_competitors = @campaign_plan.top_competitors
    assert_equal 3, top_competitors.length
    assert_equal "Market Leader", top_competitors.first["name"]
    assert_equal 40, top_competitors.first["market_share"]
    
    # Test key market insights extraction
    insights = @campaign_plan.key_market_insights
    assert_includes insights, "AI transformation"
    assert_includes insights, "Sustainability focus"
    assert_includes insights, "Price consciousness"
    assert_includes insights, "International expansion"
    assert_includes insights, "Emerging markets"
    
    # Test competitive advantages extraction
    advantages = @campaign_plan.competitive_advantages
    assert_includes advantages, "Innovation leadership"
    assert_includes advantages, "Strong partnerships"
    
    # Test market threats extraction
    threats = @campaign_plan.market_threats
    assert_includes threats, "Economic uncertainty"
    assert_includes threats, "New regulations"
    
    # Test comprehensive summary
    summary = @campaign_plan.competitive_analysis_summary
    assert_includes summary.keys, :competitive_intelligence
    assert_includes summary.keys, :market_research
    assert_includes summary.keys, :competitor_data
    assert_includes summary.keys, :industry_benchmarks
    assert_includes summary.keys, :last_updated
    assert_includes summary.keys, :is_stale
  end

  private

  def verify_competitive_intelligence_data
    competitive_data = @campaign_plan.parsed_competitive_intelligence
    
    assert competitive_data.present?
    assert competitive_data['competitive_advantages'].is_a?(Array)
    assert competitive_data['market_threats'].is_a?(Array)
    assert competitive_data['positioning_opportunities'].is_a?(Array)
    assert competitive_data['differentiation_strategies'].is_a?(Array)
    assert competitive_data['competitive_gaps'].is_a?(Array)
    assert competitive_data['strategic_recommendations'].is_a?(Array)
  end

  def verify_market_research_data
    market_data = @campaign_plan.parsed_market_research_data
    
    assert market_data.present?
    assert market_data['market_trends'].is_a?(Array)
    assert market_data['consumer_insights'].is_a?(Array)
    assert market_data['market_size_data'].is_a?(Hash)
    assert market_data['growth_opportunities'].is_a?(Array)
    assert market_data['external_factors'].is_a?(Hash)
  end

  def verify_competitor_analysis_data
    competitor_data = @campaign_plan.parsed_competitor_analysis
    
    assert competitor_data.present?
    assert competitor_data['competitors'].is_a?(Array)
    assert competitor_data['competitive_landscape'].is_a?(Hash)
    assert competitor_data['white_space_opportunities'].is_a?(Array)
    
    # Verify competitor structure
    if competitor_data['competitors'].any?
      competitor = competitor_data['competitors'].first
      assert competitor.key?('name')
      assert competitor.key?('type')
      assert competitor.key?('strengths')
      assert competitor.key?('weaknesses')
    end
  end

  def verify_industry_benchmarks_data
    benchmark_data = @campaign_plan.parsed_industry_benchmarks
    
    assert benchmark_data.present?
    assert benchmark_data['performance_benchmarks'].is_a?(Hash)
    assert benchmark_data['cost_benchmarks'].is_a?(Hash)
    assert benchmark_data['timeline_benchmarks'].is_a?(Hash)
    
    # Verify structure
    perf_benchmarks = benchmark_data['performance_benchmarks']
    assert perf_benchmarks['conversion_rates'].is_a?(Hash)
    assert perf_benchmarks['engagement_metrics'].is_a?(Hash)
    
    cost_benchmarks = benchmark_data['cost_benchmarks']
    assert cost_benchmarks['budget_allocation'].is_a?(Hash)
  end

  def verify_helper_methods_functionality
    # Test parsing methods
    assert @campaign_plan.parsed_competitive_intelligence.is_a?(Hash)
    assert @campaign_plan.parsed_market_research_data.is_a?(Hash)
    assert @campaign_plan.parsed_competitor_analysis.is_a?(Hash)
    assert @campaign_plan.parsed_industry_benchmarks.is_a?(Hash)
    
    # Test aggregation methods
    assert @campaign_plan.top_competitors.is_a?(Array)
    assert @campaign_plan.key_market_insights.is_a?(Array)
    assert @campaign_plan.competitive_advantages.is_a?(Array)
    assert @campaign_plan.market_threats.is_a?(Array)
    
    # Test summary method
    summary = @campaign_plan.competitive_analysis_summary
    assert summary.is_a?(Hash)
    assert summary.key?(:competitive_intelligence)
    assert summary.key?(:last_updated)
    assert summary.key?(:is_stale)
  end

  def setup_comprehensive_competitive_data
    @campaign_plan.update!(
      competitive_intelligence: {
        "competitive_advantages" => ["Innovation leadership", "Strong partnerships"],
        "market_threats" => ["Economic uncertainty", "New regulations"],
        "positioning_opportunities" => ["Premium segment"],
        "differentiation_strategies" => ["Technology focus"],
        "competitive_gaps" => ["Mobile presence"],
        "strategic_recommendations" => ["Digital transformation"]
      },
      market_research_data: {
        "market_trends" => ["AI transformation", "Sustainability focus"],
        "consumer_insights" => ["Price consciousness", "Quality preference"],
        "market_size_data" => {
          "total_addressable_market" => "$2.5B",
          "growth_rate" => "12%",
          "key_segments" => ["Enterprise", "SMB", "Consumer"]
        },
        "growth_opportunities" => ["International expansion", "Emerging markets"],
        "external_factors" => {
          "regulatory" => ["Data privacy", "Environmental"],
          "economic" => ["Interest rates", "Inflation"],
          "technological" => ["AI advancement", "Cloud adoption"]
        }
      },
      competitor_analysis: {
        "competitors" => [
          {
            "name" => "Market Leader",
            "type" => "direct",
            "market_share" => 40,
            "strengths" => ["Brand recognition", "Distribution"],
            "weaknesses" => ["High prices", "Legacy tech"],
            "positioning" => "Premium leader",
            "key_campaigns" => ["Brand awareness"],
            "threat_level" => "high"
          },
          {
            "name" => "Challenger",
            "type" => "direct", 
            "market_share" => 25,
            "strengths" => ["Innovation", "Agility"],
            "weaknesses" => ["Limited reach"],
            "positioning" => "Tech innovator",
            "key_campaigns" => ["Product launch"],
            "threat_level" => "medium"
          },
          {
            "name" => "Emerging Player",
            "type" => "emerging",
            "market_share" => 5,
            "strengths" => ["Fresh approach", "Digital native"],
            "weaknesses" => ["Limited resources"],
            "positioning" => "Disruptor",
            "key_campaigns" => ["Awareness building"],
            "threat_level" => "low"
          }
        ],
        "competitive_landscape" => {
          "market_saturation" => "medium",
          "barriers_to_entry" => "high",
          "innovation_pace" => "fast"
        },
        "white_space_opportunities" => ["Mid-market", "International"]
      },
      industry_benchmarks: {
        "performance_benchmarks" => {
          "conversion_rates" => {
            "email" => "3.2%",
            "social_media" => "1.8%",
            "paid_advertising" => "4.5%",
            "organic_search" => "5.2%"
          },
          "engagement_metrics" => {
            "email_open_rate" => "24%",
            "email_click_rate" => "3.5%",
            "social_engagement_rate" => "2.1%",
            "website_bounce_rate" => "52%"
          }
        },
        "cost_benchmarks" => {
          "cost_per_acquisition" => "$85",
          "cost_per_click" => "$2.50",
          "cost_per_impression" => "$1.20",
          "budget_allocation" => {
            "paid_media" => "42%",
            "content_creation" => "28%",
            "tools_and_technology" => "18%",
            "personnel" => "12%"
          }
        },
        "timeline_benchmarks" => {
          "campaign_planning" => "12 days",
          "content_creation" => "8 days",
          "campaign_execution" => "45 days",
          "performance_analysis" => "5 days"
        }
      },
      competitive_analysis_last_updated_at: Time.current
    )
  end

  def mock_successful_llm_responses
    # Create successful mock responses for all four analysis types
    mock_responses = create_mock_llm_responses
    
    mock_service = Object.new
    mock_service.define_singleton_method(:generate_content) do |options|
      if options[:prompt].include?("competitive intelligence")
        { success: true, content: mock_responses[:competitive_intelligence] }
      elsif options[:prompt].include?("market research")
        { success: true, content: mock_responses[:market_research] }
      elsif options[:prompt].include?("competitors")
        { success: true, content: mock_responses[:competitor_analysis] }
      elsif options[:prompt].include?("industry benchmarks")
        { success: true, content: mock_responses[:industry_benchmarks] }
      else
        { success: false, error: "Unknown prompt type" }
      end
    end
    
    CompetitiveAnalysisService.any_instance.stubs(:llm_service).returns(mock_service)
    
    yield
  end

  def mock_failed_llm_responses
    mock_service = Object.new
    mock_service.define_singleton_method(:generate_content) do |options|
      { success: false, error: "LLM service unavailable" }
    end
    
    CompetitiveAnalysisService.any_instance.stubs(:llm_service).returns(mock_service)
    
    yield
  end

  def create_mock_llm_responses
    {
      competitive_intelligence: {
        "competitive_advantages" => ["Strong brand recognition", "Innovative technology"],
        "market_threats" => ["New market entrants", "Economic downturn"],
        "positioning_opportunities" => ["Premium market segment", "International expansion"],
        "differentiation_strategies" => ["Technology leadership", "Customer experience"],
        "competitive_gaps" => ["Digital marketing", "Mobile optimization"],
        "strategic_recommendations" => ["Invest in digital transformation", "Expand internationally"]
      }.to_json,
      
      market_research: {
        "market_trends" => ["Digital transformation", "Sustainability focus", "Remote work adoption"],
        "consumer_insights" => ["Price sensitivity increase", "Quality over quantity preference"],
        "market_size_data" => {
          "total_addressable_market" => "$1.8B",
          "growth_rate" => "9.5%",
          "key_segments" => ["Enterprise", "Mid-market", "SMB"]
        },
        "growth_opportunities" => ["Emerging markets", "New product categories"],
        "external_factors" => {
          "regulatory" => ["Data privacy laws", "Industry compliance"],
          "economic" => ["Interest rate changes", "Inflation impact"],
          "technological" => ["AI advancement", "Cloud adoption"]
        }
      }.to_json,
      
      competitor_analysis: {
        "competitors" => [
          {
            "name" => "Industry Leader",
            "type" => "direct",
            "market_share" => "35%",
            "strengths" => ["Market presence", "Resource availability"],
            "weaknesses" => ["Legacy systems", "Slow innovation"],
            "positioning" => "Established leader",
            "key_campaigns" => ["Brand maintenance", "Market defense"],
            "threat_level" => "high"
          }
        ],
        "competitive_landscape" => {
          "market_saturation" => "medium",
          "barriers_to_entry" => "high",
          "innovation_pace" => "moderate"
        },
        "white_space_opportunities" => ["Underserved segments", "Geographic expansion"]
      }.to_json,
      
      industry_benchmarks: {
        "performance_benchmarks" => {
          "conversion_rates" => {
            "email" => "2.8%",
            "social_media" => "1.5%", 
            "paid_advertising" => "3.8%",
            "organic_search" => "4.2%"
          },
          "engagement_metrics" => {
            "email_open_rate" => "21%",
            "email_click_rate" => "2.9%",
            "social_engagement_rate" => "1.7%",
            "website_bounce_rate" => "58%"
          }
        },
        "cost_benchmarks" => {
          "cost_per_acquisition" => "$120",
          "cost_per_click" => "$2.80",
          "cost_per_impression" => "$1.60",
          "budget_allocation" => {
            "paid_media" => "40%",
            "content_creation" => "30%",
            "tools_and_technology" => "20%",
            "personnel" => "10%"
          }
        },
        "timeline_benchmarks" => {
          "campaign_planning" => "15 days",
          "content_creation" => "12 days",
          "campaign_execution" => "60 days",
          "performance_analysis" => "8 days"
        }
      }.to_json
    }
  end
end