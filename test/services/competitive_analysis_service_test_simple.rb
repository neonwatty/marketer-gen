require "test_helper"

class CompetitiveAnalysisServiceSimpleTest < ActiveSupport::TestCase
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

  test "should build prompts with correct campaign data" do
    @campaign_plan.update!(
      campaign_type: "product_launch",
      objective: "brand_awareness",
      target_audience: "tech professionals"
    )
    
    competitive_prompt = @service.send(:build_competitive_intelligence_prompt)
    market_prompt = @service.send(:build_market_research_prompt)
    competitor_prompt = @service.send(:build_competitor_analysis_prompt)
    benchmark_prompt = @service.send(:build_industry_benchmarks_prompt)
    
    # Verify competitive intelligence prompt
    assert_includes competitive_prompt, "product_launch"
    assert_includes competitive_prompt, "brand_awareness"
    assert_includes competitive_prompt, "tech professionals"
    assert_includes competitive_prompt, "JSON"
    
    # Verify market research prompt
    assert_includes market_prompt, "product_launch"
    assert_includes market_prompt, "brand_awareness"
    assert_includes market_prompt, "tech professionals"
    
    # Verify competitor analysis prompt  
    assert_includes competitor_prompt, "product_launch"
    assert_includes competitor_prompt, "brand_awareness"
    
    # Verify industry benchmarks prompt
    assert_includes benchmark_prompt, "product_launch"
    assert_includes benchmark_prompt, "brand_awareness"
  end

  test "should provide comprehensive default responses" do
    competitive_default = @service.send(:default_competitive_intelligence)
    market_default = @service.send(:default_market_research)
    competitor_default = @service.send(:default_competitor_analysis) 
    benchmark_default = @service.send(:default_industry_benchmarks)
    
    # Verify structure and content
    assert competitive_default["competitive_advantages"].is_a?(Array)
    assert competitive_default["market_threats"].is_a?(Array)
    assert_not_empty competitive_default["competitive_advantages"]
    assert_not_empty competitive_default["market_threats"]
    
    assert market_default["market_trends"].is_a?(Array)
    assert market_default["market_size_data"].is_a?(Hash)
    assert_not_empty market_default["market_trends"]
    
    assert competitor_default["competitors"].is_a?(Array)
    assert competitor_default["competitive_landscape"].is_a?(Hash)
    assert_not_empty competitor_default["competitors"]
    
    assert benchmark_default["performance_benchmarks"].is_a?(Hash)
    assert benchmark_default["cost_benchmarks"].is_a?(Hash)
    assert_not_empty benchmark_default["performance_benchmarks"]
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
end