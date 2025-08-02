require 'test_helper'

class Api::V1::LlmIntegrationControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @brand = brands(:one)
    sign_in_as(@user)
    
    # Mock LLM service responses
    mock_llm_responses
  end

  test "should generate content with brand compliance" do
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "email_subject",
        context: {
          product_name: "AI Analytics Pro",
          target_audience: "enterprise customers",
          campaign_goal: "product_launch"
        },
        provider_preference: "openai"
      }
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_not_nil response_data["generated_content"]
    assert_not_nil response_data["brand_compliance_score"]
    assert response_data["brand_compliance_score"] >= 0.90
    assert_not_nil response_data["generation_metadata"]
    assert_equal "openai", response_data["provider_used"]
    
    # Should create generation request record
    assert_difference 'LlmIntegration::ContentGenerationRequest.count', 1 do
      # Record should be created (already happened in request)
    end
  end

  test "should validate content generation parameters" do
    # Test missing brand_id
    post "/api/v1/llm_integration/generate_content", params: {
      content_request: {
        type: "email_subject",
        context: { product_name: "Test Product" }
      }
    }
    
    assert_response :bad_request
    error_data = JSON.parse(response.body)
    assert_includes error_data["errors"], "brand_id is required"
    
    # Test invalid content type
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "invalid_type",
        context: { product_name: "Test Product" }
      }
    }
    
    assert_response :bad_request
    error_data = JSON.parse(response.body)
    assert_includes error_data["errors"], "invalid content type"
    
    # Test missing required context
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "email_subject",
        context: {}
      }
    }
    
    assert_response :bad_request
    error_data = JSON.parse(response.body)
    assert_includes error_data["errors"], "insufficient context provided"
  end

  test "should handle provider failover gracefully" do
    # Mock primary provider failure
    stub_request(:post, /api\.openai\.com/)
      .to_return(status: 503, body: { error: "Service unavailable" }.to_json)
    
    # Mock successful fallback provider
    stub_request(:post, /api\.anthropic\.com/)
      .to_return(status: 200, body: anthropic_success_response.to_json)
    
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "social_media_post",
        context: { topic: "product innovation" },
        provider_preference: "openai",
        enable_failover: true
      }
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_equal "anthropic", response_data["provider_used"]
    assert response_data["failover_occurred"]
    assert_not_nil response_data["generated_content"]
    assert response_data["brand_compliance_score"] >= 0.90
  end

  test "should generate multiple content variants for A/B testing" do
    post "/api/v1/llm_integration/generate_variants", params: {
      brand_id: @brand.id,
      base_content: "Transform your business with AI analytics",
      variant_count: 4,
      optimization_goals: ["engagement", "conversion"],
      content_type: "landing_page_headline"
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_equal 4, response_data["variants"].length
    
    response_data["variants"].each_with_index do |variant, index|
      assert_not_nil variant["content"]
      assert_not_equal "Transform your business with AI analytics", variant["content"]
      assert_not_nil variant["optimization_strategy"]
      assert variant["brand_compliance_score"] >= 0.90
      assert_not_nil variant["predicted_performance_lift"]
    end
    
    # Variants should be sufficiently different
    contents = response_data["variants"].map { |v| v["content"] }
    assert_equal contents.uniq.length, contents.length, "Variants should be unique"
  end

  test "should optimize content based on performance goals" do
    post "/api/v1/llm_integration/optimize_content", params: {
      brand_id: @brand.id,
      original_content: "We have a good product for your business",
      optimization_goals: {
        primary: "brand_alignment",
        secondary: "engagement"
      },
      target_audience: "enterprise_executives",
      content_type: "email_body"
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_not_nil response_data["optimized_content"]
    assert_not_equal "We have a good product for your business", response_data["optimized_content"]
    assert response_data["improvement_score"] > 0
    assert_not_empty response_data["optimization_details"]
    assert response_data["brand_compliance_score"] >= 0.95
    
    optimization_details = response_data["optimization_details"]
    assert_includes optimization_details.keys, "improvements_made"
    assert_includes optimization_details.keys, "optimization_rationale"
  end

  test "should provide real-time brand compliance checking" do
    post "/api/v1/llm_integration/check_brand_compliance", params: {
      brand_id: @brand.id,
      content: "Our revolutionary AI platform delivers amazing results that will blow your mind!",
      real_time: true
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_includes response_data.keys, "compliance_score"
    assert_includes response_data.keys, "compliance_details"
    assert_includes response_data.keys, "suggestions"
    
    # Should identify tone issues
    assert response_data["compliance_score"] < 0.90
    assert_not_empty response_data["compliance_details"]["violations"]
    assert_includes response_data["compliance_details"]["violations"].first["type"], "tone"
  end

  test "should start conversational campaign intake session" do
    post "/api/v1/llm_integration/start_conversation", params: {
      brand_id: @brand.id,
      conversation_type: "campaign_setup",
      user_preferences: {
        communication_style: "detailed",
        experience_level: "intermediate"
      }
    }
    
    assert_response :created
    response_data = JSON.parse(response.body)
    
    assert_not_nil response_data["session_id"]
    assert_equal "campaign_setup", response_data["conversation_type"]
    assert_not_nil response_data["initial_message"]
    assert_not_empty response_data["suggested_responses"]
    
    # Should create conversation session record
    session = LlmIntegration::ConversationSession.find(response_data["session_id"])
    assert_equal @user.id, session.user_id
    assert_equal @brand.id, session.brand_id
  end

  test "should process conversational messages and extract campaign requirements" do
    # Start conversation first
    post "/api/v1/llm_integration/start_conversation", params: {
      brand_id: @brand.id,
      conversation_type: "campaign_setup"
    }
    
    session_id = JSON.parse(response.body)["session_id"]
    
    # Process user message
    post "/api/v1/llm_integration/process_message", params: {
      session_id: session_id,
      message: "I want to create an email marketing campaign for our new AI analytics product targeting enterprise customers with a budget of $15,000"
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert response_data["message_understood"]
    assert_not_empty response_data["extracted_information"]
    assert_not_nil response_data["ai_response"]
    assert_not_empty response_data["follow_up_questions"]
    
    extracted_info = response_data["extracted_information"]
    assert_equal "email_marketing", extracted_info["campaign_type"]
    assert_equal "AI analytics product", extracted_info["product"]
    assert_equal "enterprise customers", extracted_info["target_audience"]
    assert_equal 15000, extracted_info["budget"]
  end

  test "should generate comprehensive campaign plan from conversation" do
    # Create conversation session with gathered requirements
    session = LlmIntegration::ConversationSession.create!(
      user: @user,
      brand: @brand,
      session_type: :campaign_setup,
      status: :active,
      context: {
        extracted_requirements: {
          campaign_type: "product_launch",
          target_audience: "B2B professionals",
          budget: 20000,
          timeline: "8 weeks",
          primary_goal: "lead_generation"
        }
      }
    )
    
    post "/api/v1/llm_integration/generate_campaign_plan", params: {
      session_id: session.id,
      finalize_conversation: true
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_not_nil response_data["campaign_plan"]
    campaign_plan = response_data["campaign_plan"]
    
    assert_includes campaign_plan.keys, "campaign_name"
    assert_includes campaign_plan.keys, "target_audience"
    assert_includes campaign_plan.keys, "budget_allocation"
    assert_includes campaign_plan.keys, "timeline"
    assert_includes campaign_plan.keys, "content_requirements"
    assert_includes campaign_plan.keys, "success_metrics"
    
    # Should mark conversation as completed
    session.reload
    assert session.completed?
  end

  test "should provide content performance analytics" do
    # Create some test content performance data
    generated_content = LlmIntegration::GeneratedContent.create!(
      brand: @brand,
      content: "Professional analytics platform for enterprise success",
      provider_used: :openai,
      brand_compliance_score: 0.94,
      quality_score: 0.88
    )
    
    LlmIntegration::ContentPerformanceMetric.create!(
      generated_content: generated_content,
      metric_type: :email_open_rate,
      metric_value: 0.32,
      sample_size: 1200,
      channel: :email
    )
    
    get "/api/v1/llm_integration/content_analytics", params: {
      brand_id: @brand.id,
      date_range: "30_days",
      metrics: ["performance", "compliance", "optimization"]
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_includes response_data.keys, "performance_summary"
    assert_includes response_data.keys, "compliance_trends"
    assert_includes response_data.keys, "optimization_impact"
    
    performance_summary = response_data["performance_summary"]
    assert_includes performance_summary.keys, "total_content_generated"
    assert_includes performance_summary.keys, "average_brand_compliance"
    assert_includes performance_summary.keys, "average_quality_score"
  end

  test "should handle rate limiting gracefully" do
    # Simulate rate limit exceeded
    LlmIntegration::RateLimiter.any_instance.stubs(:can_make_request?).returns(false)
    LlmIntegration::RateLimiter.any_instance.stubs(:time_until_reset).returns(45)
    
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "email_subject",
        context: { product_name: "Test Product" }
      }
    }
    
    assert_response :too_many_requests
    response_data = JSON.parse(response.body)
    
    assert_equal "Rate limit exceeded", response_data["error"]
    assert_equal 45, response_data["retry_after_seconds"]
    assert_not_nil response_data["rate_limit_info"]
  end

  test "should require authentication for all endpoints" do
    sign_out
    
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: { type: "email_subject" }
    }
    
    assert_response :unauthorized
    
    get "/api/v1/llm_integration/content_analytics"
    assert_response :unauthorized
    
    post "/api/v1/llm_integration/start_conversation"
    assert_response :unauthorized
  end

  test "should enforce brand access permissions" do
    other_brand = brands(:two)
    
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: other_brand.id,
      content_request: {
        type: "email_subject",
        context: { product_name: "Test Product" }
      }
    }
    
    assert_response :forbidden
    error_data = JSON.parse(response.body)
    assert_includes error_data["error"], "access denied"
  end

  test "should provide provider status and health information" do
    get "/api/v1/llm_integration/provider_status"
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_includes response_data.keys, "providers"
    
    response_data["providers"].each do |provider_name, status|
      assert_includes status.keys, "status"
      assert_includes status.keys, "response_time"
      assert_includes status.keys, "rate_limit_remaining"
      assert_includes ["healthy", "degraded", "unavailable"], status["status"]
    end
  end

  test "should handle content generation errors gracefully" do
    # Mock LLM service error
    LlmService.any_instance.stubs(:analyze).raises(StandardError.new("API Error"))
    
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "email_subject",
        context: { product_name: "Test Product" }
      }
    }
    
    assert_response :internal_server_error
    response_data = JSON.parse(response.body)
    
    assert_equal "Content generation failed", response_data["error"]
    assert_not_nil response_data["error_id"]
    assert_includes response_data.keys, "retry_recommended"
  end

  private

  def mock_llm_responses
    # Mock successful OpenAI response
    stub_request(:post, /api\.openai\.com/)
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                content: "Innovative AI Analytics Platform: Transform Enterprise Data into Strategic Business Insights"
              }
            }
          ]
        }.to_json
      )
  end

  def anthropic_success_response
    {
      content: [
        {
          text: "Enterprise AI Analytics: Unlock Data-Driven Business Intelligence for Strategic Growth"
        }
      ]
    }
  end

  def sign_out
    delete "/sessions/#{@user.sessions.last.id}" if @user.sessions.any?
  end
end