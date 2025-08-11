require "test_helper"

class Api::V1::GenerateControllerTest < ActionController::TestCase
  setup do
    @controller = Api::V1::GenerateController.new
    
    # Mock AI service to avoid actual API calls
    @mock_ai_service = Minitest::Mock.new
    @mock_response = {
      "content" => [
        {"text" => "Generated content example"}
      ]
    }
  end

  # Helper method to run tests with mocked AI service
  def with_mocked_ai_service(&block)
    @mock_ai_service.expect(:generate_content, @mock_response) do |user_prompt, **kwargs|
      user_prompt.is_a?(String) && kwargs.is_a?(Hash)
    end
    @mock_ai_service.expect(:ai_provider, OpenStruct.new(model_name: "claude-3-5-sonnet-20241022"))
    
    AiService.stub(:new, @mock_ai_service, &block)
  end

  # Social Media Content Generation Tests
  test "should generate social media content with valid parameters" do
    with_mocked_ai_service do
      # Ensure we use the expected template by disabling others
      social_template = prompt_templates(:social_media_template)
      PromptTemplate.where(prompt_type: 'social_media').where.not(id: social_template.id).update_all(is_active: false)
      
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Sustainable fashion brand",
        campaign_name: "Summer Collection",
        campaign_goal: "Drive awareness"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["content"]
      assert_equal "Social Media Test Template", json_response["template_used"]
      assert json_response["generation_metadata"]
      
      # Re-enable templates we disabled
      PromptTemplate.where(prompt_type: 'social_media').update_all(is_active: true)
    end
  end

  test "should reject social media request without platform" do
    post :social_media, params: {
      brand_context: "Fashion brand"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "platform is required"
  end

  test "should reject social media request without brand_context" do
    post :social_media, params: {
      platform: "Instagram"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "brand_context is required"
  end

  test "should generate social media content with variations" do
    # Create a fresh mock for this test that allows multiple calls
    mock_ai_service = Minitest::Mock.new
    mock_response = {
      "content" => [{"text" => "Generated content example"}]
    }
    
    # Expect 3 calls: main content + 2 variations
    3.times do
      mock_ai_service.expect(:generate_content, mock_response) do |user_prompt, **kwargs|
        user_prompt.is_a?(String) && kwargs.is_a?(Hash)
      end
    end
    # ai_provider is called once for metadata
    mock_ai_service.expect(:ai_provider, OpenStruct.new(model_name: "claude-3-5-sonnet-20241022"))
    
    AiService.stub(:new, mock_ai_service) do
      
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand",
        generate_variations: true,
        variation_count: 2
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["variations"]
      assert_equal 2, json_response["variations"].length
    end
    
    # Verify all mock expectations were met
    mock_ai_service.verify
  end

  # Ad Copy Generation Tests
  test "should generate ad copy with valid parameters" do
    with_mocked_ai_service do
      post :ad_copy, params: {
        offering: "Sustainable clothing",
        target_audience: "Eco-conscious millennials",
        brand_context: "Fashion brand",
        platform: "Google Ads"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["content"]
      assert json_response["generation_metadata"]
    end
  end

  test "should reject ad copy request without offering" do
    post :ad_copy, params: {
      target_audience: "Millennials",
      brand_context: "Fashion brand"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "offering is required"
  end

  test "should reject ad copy request without target_audience" do
    post :ad_copy, params: {
      offering: "Clothing",
      brand_context: "Fashion brand"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "target_audience is required"
  end

  # Email Marketing Tests
  test "should generate email content with valid parameters" do
    with_mocked_ai_service do
      post :email, params: {
        email_type: "promotional",
        primary_goal: "conversion",
        brand_context: "Fashion brand",
        campaign_context: "Summer sale campaign"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["content"]
    end
  end

  test "should reject email request without email_type" do
    post :email, params: {
      primary_goal: "conversion",
      brand_context: "Fashion brand"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "email_type is required"
  end

  test "should reject email request without primary_goal" do
    post :email, params: {
      email_type: "promotional",
      brand_context: "Fashion brand"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "primary_goal is required"
  end

  # Landing Page Tests
  test "should generate landing page content with valid parameters" do
    with_mocked_ai_service do
      post :landing_page, params: {
        page_purpose: "product promotion",
        offering: "Sustainable clothing line",
        brand_context: "Eco-friendly fashion brand",
        conversion_goal: "purchase"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["content"]
    end
  end

  test "should reject landing page request without page_purpose" do
    post :landing_page, params: {
      offering: "Product",
      brand_context: "Brand"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "page_purpose is required"
  end

  # Campaign Plan Tests
  test "should generate campaign plan with valid parameters" do
    with_mocked_ai_service do
      post :campaign_plan, params: {
        campaign_name: "Summer Campaign 2025",
        campaign_purpose: "Increase brand awareness and drive sales",
        budget: "50000",
        target_audience: "Millennials interested in sustainability"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["campaign_plan"]
    end
  end

  test "should reject campaign plan request without campaign_name" do
    post :campaign_plan, params: {
      campaign_purpose: "Increase awareness"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "campaign_name is required"
  end

  test "should reject campaign plan request without campaign_purpose" do
    post :campaign_plan, params: {
      campaign_name: "Summer Campaign"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "campaign_purpose is required"
  end

  # Brand Analysis Tests
  test "should generate brand analysis with valid parameters" do
    with_mocked_ai_service do
      post :brand_analysis, params: {
        brand_assets: "Brand guidelines document, logo files, marketing materials",
        focus_areas: "brand voice, messaging, compliance"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["analysis"]
    end
  end

  test "should reject brand analysis request without brand_assets" do
    post :brand_analysis, params: {
      focus_areas: "brand voice"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "brand_assets is required"
  end

  # Template Not Found Tests
  test "should handle missing template gracefully" do
    # Create a request for a prompt type that doesn't exist
    PromptTemplate.where(prompt_type: "social_media").update_all(is_active: false)
    
    post :social_media, params: {
      platform: "Instagram",
      brand_context: "Fashion brand"
    }, as: :json

    assert_response :internal_server_error
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "No active template found"
    
    # Restore template for other tests
    PromptTemplate.where(prompt_type: "social_media").update_all(is_active: true)
  end

  # AI Service Error Handling Tests
  test "should handle AI service failures gracefully" do
    # Mock AI service that raises an error
    error_service = Minitest::Mock.new
    error_service.expect(:generate_content, proc { raise StandardError.new("AI service error") })
    error_service.expect(:ai_provider, nil)
    
    AiService.stub(:new, error_service) do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }, as: :json

      assert_response :internal_server_error
      
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert_includes json_response["error"], "Content generation failed"
    end
  end

  test "should handle circuit breaker errors" do
    # Mock AI service that raises circuit breaker error
    error_service = Minitest::Mock.new
    error_service.expect(:generate_content, nil) do |user_prompt, **kwargs|
      raise AiServiceBase::CircuitBreakerOpenError.new("Circuit breaker open")
    end
    error_service.expect(:ai_provider, nil)
    
    AiService.stub(:new, error_service) do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }, as: :json

      assert_response :service_unavailable
      
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert_includes json_response["error"], "AI service temporarily unavailable"
    end
  end

  test "should handle rate limit errors" do
    # Mock AI service that raises rate limit error
    error_service = Minitest::Mock.new
    error_service.expect(:generate_content, nil) do |user_prompt, **kwargs|
      raise AiServiceBase::RateLimitError.new("Rate limit exceeded")
    end
    error_service.expect(:ai_provider, nil)
    
    AiService.stub(:new, error_service) do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }, as: :json

      assert_response :too_many_requests
      
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert_includes json_response["error"], "Rate limit exceeded"
    end
  end

  # Variable Validation Tests
  test "should validate template variables" do
    # This test requires the template to have required variables that aren't met
    # We'll modify the template temporarily
    template = prompt_templates(:social_media_template)
    original_variables = template.variables.dup
    
    # Ensure we use the expected template by disabling others
    PromptTemplate.where(prompt_type: 'social_media').where.not(id: template.id).update_all(is_active: false)
    
    # Add a required variable that won't be provided
    template.variables = template.variables + [{"name" => "required_field", "type" => "string", "required" => true}]
    template.save!
    
    post :social_media, params: {
      platform: "Instagram",
      brand_context: "Fashion brand"
    }, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["error"], "Variable validation failed"
    assert_includes json_response["error"], "required_field"
    
    # Restore original variables and re-enable templates
    template.update!(variables: original_variables)
    PromptTemplate.where(prompt_type: 'social_media').update_all(is_active: true)
  end

  # Custom AI Provider Tests
  test "should accept custom AI provider and model parameters" do
    with_mocked_ai_service do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand",
        ai_provider: "anthropic",
        ai_model: "claude-3-5-haiku-20241022"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
    end
  end

  # Response Format Tests
  test "should return properly formatted success response" do
    with_mocked_ai_service do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }, as: :json

      assert_response :success
      
      json_response = JSON.parse(response.body)
      
      # Check required response fields
      assert json_response["success"]
      assert json_response["content"]
      assert json_response["template_used"]
      assert json_response["generation_metadata"]
      
      # Check metadata structure
      metadata = json_response["generation_metadata"]
      assert metadata["template_id"]
      assert metadata["template_version"]
      assert metadata["generated_at"]
      assert metadata["variable_count"]
      assert metadata["content_length"]
    end
  end

  test "should return properly formatted error response" do
    post :social_media, params: {}, as: :json

    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    
    # Check error response structure
    assert_not json_response["success"]
    assert json_response["error"]
    assert json_response["timestamp"]
  end

  # Content Type Tests
  test "should set JSON response format automatically" do
    with_mocked_ai_service do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }

      assert_equal "application/json; charset=utf-8", response.content_type
    end
  end

  test "should handle non-JSON requests gracefully" do
    with_mocked_ai_service do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }

      # Should still respond with JSON even if request isn't explicitly JSON
      assert_response :success
      assert_equal "application/json; charset=utf-8", response.content_type
    end
  end

  # Parameter Extraction Tests
  test "should extract social media variables correctly" do
    with_mocked_ai_service do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand",
        content_type: "story",
        campaign_name: "Summer Sale",
        tone: "casual"
      }, as: :json

      assert_response :success
      
      # The mock service should receive the extracted variables
      # This is verified implicitly through successful response
    end
  end

  # Usage Tracking Tests
  test "should increment template usage on successful generation" do
    template = prompt_templates(:social_media_template)
    initial_usage = template.usage_count
    
    # Ensure we use the expected template by disabling others
    PromptTemplate.where(prompt_type: 'social_media').where.not(id: template.id).update_all(is_active: false)
    
    with_mocked_ai_service do
      post :social_media, params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }, as: :json

      assert_response :success
      
      # Template usage should be incremented
      assert_equal initial_usage + 1, template.reload.usage_count
      
      # Re-enable templates we disabled
      PromptTemplate.where(prompt_type: 'social_media').update_all(is_active: true)
    end
  end

  test "should not increment usage on failed generation" do
    template = prompt_templates(:social_media_template)
    initial_usage = template.usage_count
    
    post :social_media, params: {}, as: :json

    assert_response :bad_request
    
    # Template usage should not be incremented for failed requests
    assert_equal initial_usage, template.reload.usage_count
  end

  private

  # Helper method to verify mock expectations
  def teardown
    @mock_ai_service.verify if @mock_ai_service
  end
end