require 'test_helper'

class LlmBrandSystemIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @brand = brands(:one)
    sign_in_as(@user)
    
    # Mock LLM responses for testing
    mock_llm_integration_responses
  end

  test "should integrate LLM content generation with existing brand compliance system" do
    # Test end-to-end integration with brand compliance
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "social_media_post",
        platform: "linkedin",
        topic: "product announcement",
        target_audience: "B2B professionals"
      }
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_not_nil response_data["generated_content"]
    assert response_data["brand_compliance_score"] >= 0.95
    assert_not_empty response_data["compliance_details"]
    
    # Should have created compliance result record
    compliance_result = ComplianceResult.last
    assert_equal @brand.id, compliance_result.brand_id
    assert_not_nil compliance_result.content_analyzed
    assert_not_nil compliance_result.overall_score
  end

  test "should sync LLM-generated content with brand analysis workflow" do
    # Create brand analysis job
    brand_analysis_job_id = BrandAnalysisJob.perform_later(@brand.id).job_id
    
    # Generate content using LLM integration
    post "/api/v1/llm_integration/generate_with_analysis", params: {
      brand_id: @brand.id,
      content_type: "email_campaign",
      analysis_job_id: brand_analysis_job_id,
      requirements: {
        subject_line: true,
        body_content: true,
        cta_optimization: true
      }
    }
    
    assert_response :accepted  # Async processing
    response_data = JSON.parse(response.body)
    
    assert_not_nil response_data["processing_id"]
    assert_equal "processing", response_data["status"]
    
    # Check integration status endpoint
    get "/api/v1/llm_integration/status/#{response_data['processing_id']}"
    assert_response :success
    
    status_data = JSON.parse(response.body)
    assert_includes ["processing", "completed"], status_data["status"]
  end

  test "should integrate with journey builder for content generation within journey steps" do
    journey = journeys(:onboarding_sequence)
    journey_step = journey_steps(:welcome_email)
    
    # Request LLM content generation for specific journey step
    patch "/api/v1/journeys/#{journey.id}/steps/#{journey_step.id}/generate_content", params: {
      llm_provider: "openai",
      content_requirements: {
        personalization_level: "high",
        brand_voice_strength: "strong",
        call_to_action: "schedule_demo"
      }
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    # Should update journey step with generated content
    journey_step.reload
    assert_not_nil journey_step.content
    assert_includes journey_step.content, "welcome"
    
    # Should maintain journey flow integrity
    assert response_data["journey_flow_validated"]
    assert_not_empty response_data["next_step_suggestions"]
  end

  test "should integrate LLM optimization with existing A/B testing system" do
    campaign = campaigns(:product_launch)
    
    # Create A/B test with LLM-optimized variants
    post "/api/v1/campaigns/#{campaign.id}/ab_tests", params: {
      test_name: "LLM Optimized Email Subject Lines",
      llm_optimization: {
        enabled: true,
        variant_count: 4,
        optimization_goals: ["open_rate", "click_through_rate"]
      },
      base_content: {
        subject: "Introducing Our New Product",
        preview: "Revolutionary features await"
      }
    }
    
    assert_response :created
    ab_test_data = JSON.parse(response.body)
    
    ab_test = AbTest.find(ab_test_data["id"])
    assert_equal 4, ab_test.ab_test_variants.count
    
    # Each variant should have LLM-generated optimized content
    ab_test.ab_test_variants.each do |variant|
      assert_not_nil variant.content
      assert_not_equal "Introducing Our New Product", variant.content["subject"]
      assert_not_nil variant.metadata["llm_optimization_strategy"]
    end
  end

  test "should integrate with campaign planning system for automated content creation" do
    campaign_plan = campaign_plans(:q4_product_launch)
    
    # Request automated content generation for entire campaign plan
    post "/api/v1/campaign_plans/#{campaign_plan.id}/generate_content_suite", params: {
      llm_integration: {
        content_types: ["email_sequence", "social_media_posts", "ad_copy", "landing_page_copy"],
        brand_consistency_level: "high",
        personalization_segments: 3
      }
    }
    
    assert_response :accepted
    response_data = JSON.parse(response.body)
    
    assert_not_nil response_data["generation_job_id"]
    
    # Check generation progress
    get "/api/v1/campaign_plans/#{campaign_plan.id}/content_generation_status"
    assert_response :success
    
    status_data = JSON.parse(response.body)
    assert_includes ["queued", "processing", "completed"], status_data["status"]
    assert_not_nil status_data["progress_percentage"]
  end

  test "should maintain brand compliance across multi-channel content generation" do
    channels = ["email", "social_media", "display_ads", "landing_pages"]
    content_suite_id = SecureRandom.uuid
    
    channels.each do |channel|
      post "/api/v1/llm_integration/generate_channel_content", params: {
        brand_id: @brand.id,
        channel: channel,
        content_suite_id: content_suite_id,
        base_message: "Discover our innovative AI platform",
        compliance_requirements: {
          minimum_brand_score: 0.95,
          tone_consistency: true,
          message_alignment: true
        }
      }
      
      assert_response :success
      channel_data = JSON.parse(response.body)
      
      assert channel_data["brand_compliance_score"] >= 0.95
      assert_not_nil channel_data["channel_optimized_content"]
      assert_equal channel, channel_data["target_channel"]
    end
    
    # Check cross-channel consistency
    get "/api/v1/llm_integration/content_suites/#{content_suite_id}/consistency_analysis"
    assert_response :success
    
    consistency_data = JSON.parse(response.body)
    assert consistency_data["cross_channel_consistency_score"] >= 0.90
    assert_not_empty consistency_data["consistency_recommendations"]
  end

  test "should integrate with real-time brand compliance monitoring" do
    # Set up WebSocket connection for real-time monitoring
    # Note: In actual implementation, this would use ActionCable
    
    content_stream = [
      "Our innovative solution transforms business operations",
      "Amazing product that will blow your mind!!!",  # Should trigger compliance alert
      "Professional analytics platform with proven ROI"
    ]
    
    content_stream.each_with_index do |content, index|
      post "/api/v1/llm_integration/real_time_compliance_check", params: {
        brand_id: @brand.id,
        content: content,
        content_id: "stream_#{index}",
        real_time_monitoring: true
      }
      
      response_data = JSON.parse(response.body)
      
      if index == 1  # Non-compliant content
        assert response_data["compliance_alert"]
        assert response_data["brand_compliance_score"] < 0.8
        assert_not_empty response_data["immediate_suggestions"]
      else
        refute response_data["compliance_alert"]
        assert response_data["brand_compliance_score"] >= 0.9
      end
    end
  end

  test "should integrate performance analytics with content optimization learning" do
    # Generate content with performance tracking
    post "/api/v1/llm_integration/generate_with_tracking", params: {
      brand_id: @brand.id,
      content_type: "email_subject",
      tracking_enabled: true,
      performance_goals: {
        target_open_rate: 0.25,
        target_click_rate: 0.05
      }
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    content_id = response_data["content_id"]
    
    # Simulate performance data collection
    performance_data = {
      content_id: content_id,
      impressions: 1000,
      opens: 280,
      clicks: 65,
      conversions: 12,
      engagement_time: 45
    }
    
    patch "/api/v1/llm_integration/content/#{content_id}/record_performance", params: {
      performance: performance_data
    }
    
    assert_response :success
    
    # Check if performance data feeds back into optimization system
    get "/api/v1/llm_integration/optimization_insights"
    assert_response :success
    
    insights_data = JSON.parse(response.body)
    assert_not_empty insights_data["learned_optimizations"]
    assert_not_nil insights_data["performance_trends"]
  end

  test "should handle LLM provider failover without disrupting brand compliance" do
    # Simulate primary provider (OpenAI) failure
    stub_request(:post, /api\.openai\.com/)
      .to_return(status: 503, body: { error: "Service unavailable" }.to_json)
    
    # Mock successful Anthropic response
    stub_request(:post, /api\.anthropic\.com/)
      .to_return(status: 200, body: anthropic_success_response.to_json)
    
    post "/api/v1/llm_integration/generate_content", params: {
      brand_id: @brand.id,
      content_request: {
        type: "marketing_email",
        failover_enabled: true,
        maintain_brand_compliance: true
      }
    }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    
    assert_equal "anthropic", response_data["provider_used"]
    assert response_data["failover_occurred"]
    assert response_data["brand_compliance_score"] >= 0.95
    assert_not_nil response_data["generated_content"]
  end

  test "should integrate with content version control system" do
    content_repository = content_repositories(:marketing_assets)
    
    # Generate content with version control integration
    post "/api/v1/content_repositories/#{content_repository.id}/llm_generate", params: {
      content_spec: {
        type: "blog_post_intro",
        topic: "AI in business transformation",
        word_count: 150
      },
      version_control: {
        create_version: true,
        commit_message: "LLM generated blog intro - AI transformation topic",
        reviewer_required: true
      }
    }
    
    assert_response :created
    response_data = JSON.parse(response.body)
    
    # Should create new content version
    content_version = ContentVersion.find(response_data["content_version_id"])
    assert_not_nil content_version
    assert_equal "LLM generated blog intro - AI transformation topic", content_version.commit_message
    assert_equal "pending_review", content_version.status
    
    # Should integrate with approval workflow
    assert_not_nil content_version.content_approval
    assert_equal @user.id, content_version.content_approval.submitted_by_id
  end

  test "should support collaborative content creation with LLM assistance" do
    # Start collaborative session
    post "/api/v1/llm_integration/collaborative_sessions", params: {
      brand_id: @brand.id,
      session_type: "campaign_content_creation",
      collaborators: [@user.id],
      llm_assistance_level: "high"
    }
    
    assert_response :created
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]
    
    # Add content with LLM suggestions
    post "/api/v1/llm_integration/collaborative_sessions/#{session_id}/add_content", params: {
      content: "Our new platform revolutionizes data analytics",
      request_llm_suggestions: true,
      suggestion_types: ["improvements", "variations", "tone_adjustments"]
    }
    
    assert_response :success
    content_data = JSON.parse(response.body)
    
    assert_not_empty content_data["llm_suggestions"]
    assert_includes content_data["llm_suggestions"].keys, "improvements"
    assert_includes content_data["llm_suggestions"].keys, "variations"
    assert_includes content_data["llm_suggestions"].keys, "tone_adjustments"
    
    # Test real-time collaboration features
    get "/api/v1/llm_integration/collaborative_sessions/#{session_id}/status"
    assert_response :success
    
    status_data = JSON.parse(response.body)
    assert_equal "active", status_data["status"]
    assert_equal 1, status_data["active_collaborators"]
  end

  private

  def mock_llm_integration_responses
    # Mock OpenAI responses
    stub_request(:post, /api\.openai\.com/)
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                content: "Professional AI-powered analytics platform that transforms enterprise data into actionable business insights."
              }
            }
          ]
        }.to_json
      )
    
    # Mock Anthropic responses for failover testing
    stub_request(:post, /api\.anthropic\.com/)
      .to_return(
        status: 200,
        body: anthropic_success_response.to_json
      )
  end

  def anthropic_success_response
    {
      content: [
        {
          text: "Our enterprise-grade analytics solution delivers measurable business value through advanced AI-driven insights and data visualization."
        }
      ]
    }
  end
end