# frozen_string_literal: true

require "test_helper"

class CampaignIntelligenceServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @campaign_plan = campaign_plans(:one)
    @service = CampaignIntelligenceService.new(@campaign_plan)
  end

  test "should initialize with campaign_plan" do
    service = CampaignIntelligenceService.new(@campaign_plan)
    assert_equal @campaign_plan, service.campaign_plan
  end

  test "call should generate comprehensive intelligence successfully" do
    # Stub the LLM service to return successful responses
    mock_llm_service = Minitest::Mock.new
    mock_llm_service.expect :generate_content, { success: true, content: '{"test": "data"}' }, [Hash]
    mock_llm_service.expect :generate_content, { success: true, content: '{"test": "data"}' }, [Hash]
    mock_llm_service.expect :generate_content, { success: true, content: '{"test": "data"}' }, [Hash]
    mock_llm_service.expect :generate_content, { success: true, content: '{"test": "data"}' }, [Hash]
    mock_llm_service.expect :generate_content, { success: true, content: '{"test": "data"}' }, [Hash]
    
    @service.stub :llm_service, mock_llm_service do
      # Mock the CompetitiveAnalysisService
      CompetitiveAnalysisService.stub :new, -> (plan) {
        mock_competitive_service = Minitest::Mock.new
        mock_competitive_service.expect :perform_analysis, { success: true, data: { "competitive" => "data" } }
        mock_competitive_service
      } do
        result = @service.call
        
        assert result[:success]
        assert_equal @campaign_plan.id, result[:data][:campaign_plan_id]
        assert_includes result[:data].keys, :insights_generated
        assert_includes result[:data].keys, :confidence_average
        assert_includes result[:data].keys, :analysis_types
      end
    end
    
    mock_llm_service.verify
  end

  test "call should handle errors gracefully" do
    # Force an error by passing nil
    service = CampaignIntelligenceService.new(nil)
    result = service.call
    
    assert_not result[:success]
    assert_includes result.keys, :error
  end

  test "generate_comprehensive_intelligence should create multiple insight types" do
    # Clear existing insights
    @campaign_plan.campaign_insights.destroy_all
    
    # Mock successful LLM responses
    mock_llm_service = Minitest::Mock.new
    5.times do
      mock_llm_service.expect :generate_content, { success: true, content: '{"test": "data"}' }, [Hash]
    end
    
    @service.stub :llm_service, mock_llm_service do
      # Mock the CompetitiveAnalysisService
      CompetitiveAnalysisService.stub :new, -> (plan) {
        mock_competitive_service = Minitest::Mock.new
        mock_competitive_service.expect :perform_analysis, { success: true, data: { "competitive" => "data" } }
        mock_competitive_service
      } do
        result = @service.generate_comprehensive_intelligence
        
        assert_equal 6, result[:insights_count]  # 6 different types of insights
        assert result[:avg_confidence] > 0
        assert_equal 6, result[:analysis_types].count
        
        # Verify all insight types are created
        expected_types = [
          'competitive_analysis',
          'market_trends', 
          'performance_prediction',
          'strategic_recommendation',
          'audience_intelligence',
          'budget_optimization'
        ]
        
        created_types = result[:analysis_types]
        expected_types.each do |type|
          assert_includes created_types, type
        end
      end
    end
    
    mock_llm_service.verify
  end

  test "generate_competitive_intelligence should integrate with CompetitiveAnalysisService" do
    @campaign_plan.campaign_insights.destroy_all
    
    # Mock successful competitive analysis
    competitive_data = { "competitive_advantages" => ["advantage1"], "threats" => ["threat1"] }
    
    CompetitiveAnalysisService.stub :new, -> (plan) {
      mock_service = Minitest::Mock.new
      mock_service.expect :perform_analysis, { success: true, data: competitive_data }
      mock_service
    } do
      result = @service.send(:generate_competitive_intelligence)
      
      assert_equal 'competitive_analysis', result[:insight_type]
      assert_equal 0.85, result[:confidence_score]
      assert_equal competitive_data, result[:data]
      
      # Verify insight was created in database
      insight = @campaign_plan.campaign_insights.last
      assert_equal 'competitive_analysis', insight.insight_type
      assert_equal competitive_data, insight.insight_data
    end
  end

  test "generate_competitive_intelligence should handle CompetitiveAnalysisService errors" do
    @campaign_plan.campaign_insights.destroy_all
    
    # Mock failed competitive analysis
    CompetitiveAnalysisService.stub :new, -> (plan) {
      mock_service = Minitest::Mock.new
      mock_service.expect :perform_analysis, { success: false, error: "Service error" }
      mock_service
    } do
      result = @service.send(:generate_competitive_intelligence)
      
      assert_equal 'competitive_analysis', result[:insight_type]
      assert_equal 0.5, result[:confidence_score]  # Lower confidence for failed integration
      assert_instance_of Hash, result[:data]
    end
  end

  test "generate_market_trend_analysis should use LLM service" do
    @campaign_plan.campaign_insights.destroy_all
    
    market_data = { "trending_topics" => ["trend1", "trend2"], "behavior_shifts" => ["shift1"] }
    
    mock_llm_service = Minitest::Mock.new
    mock_llm_service.expect :generate_content, 
                           { success: true, content: market_data.to_json },
                           [Hash]
    
    @service.stub :llm_service, mock_llm_service do
      result = @service.send(:generate_market_trend_analysis)
      
      assert_equal 'market_trends', result[:insight_type]
      assert_equal 0.80, result[:confidence_score]
      assert_equal market_data, result[:data]
      
      # Verify insight was created in database
      insight = @campaign_plan.campaign_insights.last
      assert_equal 'market_trends', insight.insight_type
    end
    
    mock_llm_service.verify
  end

  test "generate_performance_predictions should handle LLM failures" do
    @campaign_plan.campaign_insights.destroy_all
    
    mock_llm_service = Minitest::Mock.new
    mock_llm_service.expect :generate_content, { success: false, error: "LLM error" }, [Hash]
    
    @service.stub :llm_service, mock_llm_service do
      result = @service.send(:generate_performance_predictions)
      
      assert_equal 'performance_prediction', result[:insight_type]
      assert_equal 0.45, result[:confidence_score]  # Lower confidence for default data
      assert_instance_of Hash, result[:data]
      
      # Should use default performance predictions
      assert_includes result[:data].keys, "engagement_predictions"
      assert_includes result[:data].keys, "roi_forecast"
    end
    
    mock_llm_service.verify
  end

  test "generate_strategic_recommendations should create strategic insight" do
    @campaign_plan.campaign_insights.destroy_all
    
    strategic_data = { 
      "optimization_opportunities" => [{ "area" => "content", "recommendation" => "increase video" }],
      "resource_allocation" => { "budget_reallocation" => ["suggestion1"] }
    }
    
    mock_llm_service = Minitest::Mock.new
    mock_llm_service.expect :generate_content,
                           { success: true, content: strategic_data.to_json },
                           [Hash]
    
    @service.stub :llm_service, mock_llm_service do
      result = @service.send(:generate_strategic_recommendations)
      
      assert_equal 'strategic_recommendation', result[:insight_type]
      assert_equal 0.88, result[:confidence_score]
      assert_equal strategic_data, result[:data]
    end
    
    mock_llm_service.verify
  end

  test "generate_audience_intelligence should create audience insight" do
    @campaign_plan.campaign_insights.destroy_all
    
    audience_data = {
      "audience_segments" => [{ "segment_name" => "early_adopters", "size_percentage" => "25%" }],
      "behavioral_patterns" => { "online_behavior" => ["research_heavy"] }
    }
    
    mock_llm_service = Minitest::Mock.new
    mock_llm_service.expect :generate_content,
                           { success: true, content: audience_data.to_json },
                           [Hash]
    
    @service.stub :llm_service, mock_llm_service do
      result = @service.send(:generate_audience_intelligence)
      
      assert_equal 'audience_intelligence', result[:insight_type]
      assert_equal 0.82, result[:confidence_score]
      assert_equal audience_data, result[:data]
    end
    
    mock_llm_service.verify
  end

  test "generate_budget_optimization_insights should create budget insight" do
    @campaign_plan.campaign_insights.destroy_all
    
    budget_data = {
      "optimal_allocation" => { "paid_advertising" => "45%", "content_creation" => "25%" },
      "efficiency_improvements" => [{ "area" => "automation", "potential_savings" => "15%" }]
    }
    
    mock_llm_service = Minitest::Mock.new
    mock_llm_service.expect :generate_content,
                           { success: true, content: budget_data.to_json },
                           [Hash]
    
    @service.stub :llm_service, mock_llm_service do
      result = @service.send(:generate_budget_optimization_insights)
      
      assert_equal 'budget_optimization', result[:insight_type]
      assert_equal 0.78, result[:confidence_score]
      assert_equal budget_data, result[:data]
    end
    
    mock_llm_service.verify
  end

  test "create_insight should create and return insight record" do
    @campaign_plan.campaign_insights.destroy_all
    
    insight_data = { "test" => "data", "confidence" => "high" }
    
    result = @service.send(:create_insight,
                          insight_type: 'market_trends',
                          insight_data: insight_data,
                          confidence_score: 0.85,
                          metadata: { "source" => "test" })
    
    assert_equal 'market_trends', result[:insight_type]
    assert_equal 0.85, result[:confidence_score]
    assert_includes result.keys, :insight_id
    assert_equal insight_data, result[:data]
    
    # Verify database record
    insight = CampaignInsight.find(result[:insight_id])
    assert_equal 'market_trends', insight.insight_type
    assert_equal insight_data, insight.insight_data
    assert_equal 0.85, insight.confidence_score
    assert_equal({ "source" => "test" }, insight.metadata)
  end

  test "prompt building methods should generate appropriate prompts" do
    prompts = [
      @service.send(:build_market_trend_prompt),
      @service.send(:build_performance_prediction_prompt),
      @service.send(:build_strategic_recommendations_prompt),
      @service.send(:build_audience_intelligence_prompt),
      @service.send(:build_budget_optimization_prompt)
    ]
    
    prompts.each do |prompt|
      assert_instance_of String, prompt
      assert prompt.length > 100  # Should be substantial prompts
      
      # Should include campaign context
      assert_includes prompt, @campaign_plan.campaign_type
      assert_includes prompt, @campaign_plan.objective
      
      # Should request JSON format
      assert_includes prompt, "JSON"
    end
  end

  test "response parsing methods should handle valid JSON" do
    valid_json = '{"key": "value", "array": ["item1", "item2"]}'
    
    parsers = [
      :parse_market_trend_response,
      :parse_performance_prediction_response,
      :parse_strategic_recommendations_response,
      :parse_audience_intelligence_response,
      :parse_budget_optimization_response
    ]
    
    parsers.each do |parser|
      result = @service.send(parser, valid_json)
      assert_instance_of Hash, result
      assert_equal "value", result["key"]
      assert_equal ["item1", "item2"], result["array"]
    end
  end

  test "response parsing methods should handle invalid JSON gracefully" do
    invalid_json = "invalid json content"
    
    parsers = [
      :parse_market_trend_response,
      :parse_performance_prediction_response, 
      :parse_strategic_recommendations_response,
      :parse_audience_intelligence_response,
      :parse_budget_optimization_response
    ]
    
    parsers.each do |parser|
      result = @service.send(parser, invalid_json)
      assert_instance_of Hash, result
      # Should return default response structure
      assert result.keys.count > 0
    end
  end

  test "default response methods should return proper structure" do
    defaults = [
      @service.send(:default_market_trends),
      @service.send(:default_performance_predictions),
      @service.send(:default_strategic_recommendations),
      @service.send(:default_audience_intelligence),
      @service.send(:default_budget_optimization)
    ]
    
    defaults.each do |default|
      assert_instance_of Hash, default
      assert default.keys.count > 0
      # Each default should have meaningful structure
      default.values.each do |value|
        assert [Hash, Array, String].any? { |type| value.is_a?(type) }
      end
    end
  end

  test "extract_industry_context should extract industry from brand context" do
    # Test with industry in brand context
    @campaign_plan.stub :brand_context_summary, { "industry" => "Technology" } do
      context = @service.send(:extract_industry_context)
      assert_equal "Technology", context
    end
    
    # Test with vertical in brand context
    @campaign_plan.stub :brand_context_summary, { "vertical" => "Healthcare" } do
      context = @service.send(:extract_industry_context)
      assert_equal "Healthcare", context
    end
    
    # Test with no brand context (fallback to campaign type)
    @campaign_plan.stub :brand_context_summary, {} do
      context = @service.send(:extract_industry_context)
      assert_equal @campaign_plan.campaign_type.humanize, context
    end
  end

  test "service should log service calls" do
    # Capture log output
    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(log_output)
    
    begin
      # Mock dependencies for successful call
      mock_llm_service = Minitest::Mock.new
      5.times { mock_llm_service.expect :generate_content, { success: true, content: '{"test": "data"}' }, [Hash] }
      
      @service.stub :llm_service, mock_llm_service do
        CompetitiveAnalysisService.stub :new, -> (plan) {
          mock_competitive = Minitest::Mock.new
          mock_competitive.expect :perform_analysis, { success: true, data: { "competitive" => "data" } }
          mock_competitive
        } do
          @service.call
        end
      end
      
      log_content = log_output.string
      assert_includes log_content, "CampaignIntelligenceService"
      assert_includes log_content, @campaign_plan.id.to_s
      
      mock_llm_service.verify
    ensure
      Rails.logger = original_logger
    end
  end
end