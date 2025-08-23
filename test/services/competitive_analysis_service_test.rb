require "test_helper"

class CompetitiveAnalysisServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @service = CompetitiveAnalysisService.new(@campaign_plan)
  end

  test "should initialize with campaign plan" do
    assert_equal @campaign_plan, @service.campaign_plan
  end

  test "call should enqueue CompetitiveAnalysisJob" do
    assert_enqueued_jobs 1, only: CompetitiveAnalysisJob do
      result = @service.call
      
      assert result[:success]
      assert_equal 'Competitive analysis initiated', result[:data][:message]
      assert_equal @campaign_plan.id, result[:data][:campaign_plan_id]
      assert_equal 'processing', result[:data][:status]
    end
  end

  test "call should handle errors gracefully" do
    # Mock CompetitiveAnalysisJob to raise an error
    original_method = CompetitiveAnalysisJob.method(:perform_later)
    CompetitiveAnalysisJob.define_singleton_method(:perform_later) { |*| raise StandardError.new("Job failed") }
    
    begin
      result = @service.call
      
      assert_not result[:success]
      assert_equal "Job failed", result[:error]
      assert_equal @campaign_plan.id, result[:context][:campaign_plan_id]
    ensure
      CompetitiveAnalysisJob.define_singleton_method(:perform_later, &original_method)
    end
  end

  test "perform_analysis should update campaign plan with competitive data" do
    # Mock LLM responses
    mock_llm_responses

    result = @service.perform_analysis
    
    assert result[:success]
    
    @campaign_plan.reload
    
    # Verify all fields were updated
    assert_not_nil @campaign_plan.competitive_intelligence
    assert_not_nil @campaign_plan.market_research_data
    assert_not_nil @campaign_plan.competitor_analysis  
    assert_not_nil @campaign_plan.industry_benchmarks
    assert_not_nil @campaign_plan.competitive_analysis_last_updated_at
    
    # Verify data structure
    competitive_data = @campaign_plan.parsed_competitive_intelligence
    assert_includes competitive_data.keys, 'competitive_advantages'
    assert_includes competitive_data.keys, 'market_threats'
    
    market_data = @campaign_plan.parsed_market_research_data
    assert_includes market_data.keys, 'market_trends'
    assert_includes market_data.keys, 'consumer_insights'
    
    competitor_data = @campaign_plan.parsed_competitor_analysis
    assert_includes competitor_data.keys, 'competitors'
    assert_includes competitor_data.keys, 'competitive_landscape'
    
    benchmark_data = @campaign_plan.parsed_industry_benchmarks
    assert_includes benchmark_data.keys, 'performance_benchmarks'
    assert_includes benchmark_data.keys, 'cost_benchmarks'
  end

  test "perform_analysis should handle LLM service errors" do
    # Mock LLM service to fail
    mock_service = Object.new
    def mock_service.generate_content(*args)
      { success: false, error: "LLM failed" }
    end
    
    @service.stubs(:llm_service).returns(mock_service)
    begin
      result = @service.perform_analysis
      
      assert result[:success], "Should succeed with default data even when LLM fails"
      
      @campaign_plan.reload
      
      # Should have default competitive intelligence data
      competitive_data = @campaign_plan.parsed_competitive_intelligence
      assert_includes competitive_data['competitive_advantages'], 'Market experience'
      assert_includes competitive_data['market_threats'], 'New competitors'
    ensure
      @service.unstub(:llm_service) rescue nil
    end
  end

  test "should extract industry context from campaign plan" do
    @campaign_plan.brand_context = { "industry" => "Technology" }.to_json
    
    industry = @service.send(:extract_industry_context)
    
    assert_equal "Technology", industry
  end

  test "should default to campaign type when no industry context" do
    @campaign_plan.brand_context = nil
    
    industry = @service.send(:extract_industry_context)
    
    assert_equal "Product launch", industry
  end

  test "should build competitive intelligence prompt correctly" do
    @campaign_plan.update!(
      campaign_type: "product_launch",
      objective: "brand_awareness",
      target_audience: "tech professionals"
    )
    
    prompt = @service.send(:build_competitive_intelligence_prompt)
    
    assert_includes prompt, "product_launch"
    assert_includes prompt, "brand_awareness" 
    assert_includes prompt, "tech professionals"
    assert_includes prompt, "competitive advantages"
    assert_includes prompt, "threats"
    assert_includes prompt, "JSON"
  end

  test "should build market research prompt correctly" do
    @campaign_plan.update!(
      campaign_type: "lead_generation",
      objective: "customer_acquisition",
      target_audience: "small businesses",
      budget_constraints: "$50,000"
    )
    
    prompt = @service.send(:build_market_research_prompt)
    
    assert_includes prompt, "lead_generation"
    assert_includes prompt, "customer_acquisition"
    assert_includes prompt, "small businesses" 
    assert_includes prompt, "$50,000"
    assert_includes prompt, "market trends"
    assert_includes prompt, "insights"
  end

  test "should build competitor analysis prompt correctly" do
    prompt = @service.send(:build_competitor_analysis_prompt)
    
    assert_includes prompt, "Direct competitors"
    assert_includes prompt, "Indirect competitors"
    assert_includes prompt, "market_share"
    assert_includes prompt, "strengths"
    assert_includes prompt, "weaknesses"
  end

  test "should build industry benchmarks prompt correctly" do
    prompt = @service.send(:build_industry_benchmarks_prompt)
    
    assert_includes prompt, "Performance metrics"
    assert_includes prompt, "Cost benchmarks"
    assert_includes prompt, "conversion_rates"
    assert_includes prompt, "budget_allocation"
    assert_includes prompt, "timeline_benchmarks"
  end

  test "should parse valid JSON responses correctly" do
    valid_json = { "competitive_advantages" => ["advantage1"], "market_threats" => ["threat1"] }.to_json
    
    result = @service.send(:parse_competitive_intelligence_response, valid_json)
    
    assert_equal "advantage1", result["competitive_advantages"].first
    assert_equal "threat1", result["market_threats"].first
  end

  test "should handle invalid JSON responses gracefully" do
    invalid_json = "This is not JSON"
    
    result = @service.send(:parse_competitive_intelligence_response, invalid_json)
    
    # Should return default competitive intelligence
    assert_includes result["competitive_advantages"], "Market experience"
    assert_includes result["market_threats"], "New competitors"
  end

  test "should provide comprehensive default responses" do
    competitive_default = @service.send(:default_competitive_intelligence)
    market_default = @service.send(:default_market_research)
    competitor_default = @service.send(:default_competitor_analysis) 
    benchmark_default = @service.send(:default_industry_benchmarks)
    
    # Verify structure and content
    assert competitive_default["competitive_advantages"].is_a?(Array)
    assert competitive_default["market_threats"].is_a?(Array)
    
    assert market_default["market_trends"].is_a?(Array)
    assert market_default["market_size_data"].is_a?(Hash)
    
    assert competitor_default["competitors"].is_a?(Array)
    assert competitor_default["competitive_landscape"].is_a?(Hash)
    
    assert benchmark_default["performance_benchmarks"].is_a?(Hash)
    assert benchmark_default["cost_benchmarks"].is_a?(Hash)
  end

  private

  def mock_llm_responses
    mock_service = Object.new
    
    # Mock responses for different prompt types
    responses = {
      competitive: {
        "competitive_advantages" => ["Strong brand", "Innovation"],
        "market_threats" => ["New entrants", "Economic downturn"],
        "positioning_opportunities" => ["Premium market"],
        "differentiation_strategies" => ["Technology focus"],
        "competitive_gaps" => ["Digital presence"],
        "strategic_recommendations" => ["Invest in R&D"]
      }.to_json,
      
      market: {
        "market_trends" => ["Digital transformation", "Sustainability"],
        "consumer_insights" => ["Price sensitivity", "Quality focus"],
        "market_size_data" => {
          "total_addressable_market" => "$1B",
          "growth_rate" => "8%",
          "key_segments" => ["Enterprise", "SMB"]
        },
        "growth_opportunities" => ["International expansion"],
        "external_factors" => {
          "regulatory" => ["Privacy laws"],
          "economic" => ["Inflation"],
          "technological" => ["AI adoption"]
        }
      }.to_json,
      
      competitor: {
        "competitors" => [
          {
            "name" => "Competitor X",
            "type" => "direct",
            "market_share" => "30%",
            "strengths" => ["Brand recognition"],
            "weaknesses" => ["High prices"],
            "positioning" => "Premium leader",
            "key_campaigns" => ["Brand campaign"],
            "threat_level" => "high"
          }
        ],
        "competitive_landscape" => {
          "market_saturation" => "medium",
          "barriers_to_entry" => "high",
          "innovation_pace" => "fast"
        },
        "white_space_opportunities" => ["Mid-market segment"]
      }.to_json,
      
      benchmark: {
        "performance_benchmarks" => {
          "conversion_rates" => {
            "email" => "3%",
            "social_media" => "2%",
            "paid_advertising" => "5%",
            "organic_search" => "6%"
          },
          "engagement_metrics" => {
            "email_open_rate" => "22%",
            "email_click_rate" => "3%",
            "social_engagement_rate" => "2%",
            "website_bounce_rate" => "55%"
          }
        },
        "cost_benchmarks" => {
          "cost_per_acquisition" => "$100",
          "cost_per_click" => "$2",
          "cost_per_impression" => "$1.50",
          "budget_allocation" => {
            "paid_media" => "45%",
            "content_creation" => "25%",
            "tools_and_technology" => "15%",
            "personnel" => "15%"
          }
        },
        "timeline_benchmarks" => {
          "campaign_planning" => "14 days",
          "content_creation" => "10 days",
          "campaign_execution" => "60 days",
          "performance_analysis" => "7 days"
        }
      }.to_json
    }
    
    call_count = 0
    response_order = [:competitive, :market, :competitor, :benchmark]
    
    def mock_service.generate_content(options = {})
      @call_count ||= 0
      response_order = [:competitive, :market, :competitor, :benchmark]
      responses = self.instance_variable_get(:@responses)
      
      key = response_order[@call_count % 4]
      @call_count += 1
      
      { success: true, content: responses[key] }
    end
    
    mock_service.instance_variable_set(:@responses, responses)
    
    @service.stubs(:llm_service).returns(mock_service)
    begin
      yield if block_given?
    ensure
      @service.unstub(:llm_service) rescue nil
    end
  end
end