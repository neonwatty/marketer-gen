require "test_helper"

class ContentGenerationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure we have test templates available
    @social_template = prompt_templates(:social_media_template)
    @email_template = prompt_templates(:email_template)
    @campaign_template = prompt_templates(:campaign_planning_template)
    
    # Mock AI service for integration tests
    @mock_ai_service = Minitest::Mock.new
    @mock_response = {
      "content" => [
        {"text" => "This is generated content from the AI service"}
      ]
    }
  end

  def with_mocked_ai_service(&block)
    @mock_ai_service.expect(:generate_content, @mock_response) do |user_prompt, **kwargs|
      user_prompt.is_a?(String) && kwargs.is_a?(Hash)
    end
    @mock_ai_service.expect(:ai_provider, OpenStruct.new(model_name: "claude-3-5-sonnet-20241022"))
    
    AiService.stub(:new, @mock_ai_service, &block)
  end

  # Complete workflow tests
  test "complete social media content generation workflow" do
    with_mocked_ai_service do
      # Temporarily disable other social_media templates to ensure we get the right one
      PromptTemplate.where(prompt_type: 'social_media').where.not(id: @social_template.id).update_all(is_active: false)
      
      # Step 1: Check template exists and is active
      assert @social_template.is_active?
      assert_equal "social_media", @social_template.prompt_type
      
      # Step 2: Make API request
      post "/api/v1/generate/social_media", params: {
        platform: "Instagram",
        brand_context: "Sustainable fashion brand for eco-conscious millennials",
        campaign_name: "Earth Day Collection",
        campaign_goal: "Increase brand awareness and drive engagement",
        target_audience: "Environmentally conscious consumers aged 25-40",
        tone: "inspiring and authentic",
        content_type: "carousel post"
      }, as: :json
      
      # Step 3: Verify successful response
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"], "Request should succeed"
      assert json_response["content"].present?, "Should return generated content"
      assert_equal @social_template.name, json_response["template_used"]
      
      # Step 4: Verify metadata
      metadata = json_response["generation_metadata"]
      assert metadata["template_id"].present?
      assert metadata["generated_at"].present?
      assert metadata["model_used"].present?
      assert metadata["variable_count"] > 0
      
      # Step 5: Verify template usage was tracked
      @social_template.reload
      assert @social_template.usage_count > 5  # Initial fixture value is 5
      
      # Re-enable templates we disabled
      PromptTemplate.where(prompt_type: 'social_media').update_all(is_active: true)
    end
  end

  test "complete email marketing workflow with variations" do
    # Create a fresh mock for this test that allows multiple calls
    mock_ai_service = Minitest::Mock.new
    mock_response = {
      "content" => [{"text" => "This is generated content from the AI service"}]
    }
    
    # Expect 3 calls: main content generation + 2 variations
    3.times do
      mock_ai_service.expect(:generate_content, mock_response) do |user_prompt, **kwargs|
        user_prompt.is_a?(String) && kwargs.is_a?(Hash)
      end
    end
    # ai_provider is called once for metadata
    mock_ai_service.expect(:ai_provider, OpenStruct.new(model_name: "claude-3-5-sonnet-20241022"))
    
    AiService.stub(:new, mock_ai_service) do
      
      post "/api/v1/generate/email", params: {
        email_type: "promotional",
        campaign_context: "Summer sale campaign for sustainable fashion",
        subject_focus: "Limited time offer",
        primary_goal: "drive online sales",
        target_segment: "VIP customers",
        brand_voice: "friendly and trustworthy",
        tone: "enthusiastic",
        brand_context: "Sustainable fashion brand focused on eco-friendly materials",
        generate_variations: true,
        variation_count: 2
      }, as: :json
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["content"].present?
      assert json_response["variations"].present?
      assert_equal 2, json_response["variations"].length
      
      # Verify each variation has required fields
      json_response["variations"].each_with_index do |variation, index|
        assert variation["variation_id"] == index + 1
        assert variation["content"].present?
        assert variation["temperature_used"].present?
      end
    end
    
    # Verify all mock expectations were met
    mock_ai_service.verify
  end

  test "campaign planning workflow with comprehensive parameters" do
    with_mocked_ai_service do
      post "/api/v1/generate/campaign_plan", params: {
        campaign_name: "Sustainable Fashion Week 2025",
        campaign_purpose: "Position brand as leader in sustainable fashion while driving Q2 sales",
        budget: "150000",
        start_date: "2025-04-01",
        end_date: "2025-06-30",
        target_audience: "Fashion-forward millennials and Gen Z consumers interested in sustainability",
        brand_context: "Premium sustainable fashion brand with strong ethical values and eco-friendly materials",
        additional_requirements: "Must include influencer partnerships and focus on social media engagement"
      }, as: :json
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      assert json_response["campaign_plan"].present?
      assert_equal @campaign_template.name, json_response["template_used"]
      
      # Verify campaign-specific response format
      assert_not json_response.key?("variations")  # Campaign plans don't generate variations
      assert json_response["generation_metadata"]["template_id"] == @campaign_template.id
    end
  end

  # Error handling integration tests
  test "handles missing required parameters gracefully" do
    post "/api/v1/generate/social_media", params: {
      brand_context: "Fashion brand"
      # Missing required 'platform' parameter
    }, as: :json
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["error"].include?("platform is required")
    assert json_response["timestamp"].present?
  end

  test "handles template not found scenario" do
    # Temporarily deactivate all social media templates
    PromptTemplate.where(prompt_type: "social_media").update_all(is_active: false)
    
    post "/api/v1/generate/social_media", params: {
      platform: "Instagram",
      brand_context: "Fashion brand"
    }, as: :json
    
    assert_response :internal_server_error
    
    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["error"].include?("No active template found")
    
    # Restore templates for other tests
    PromptTemplate.where(prompt_type: "social_media").update_all(is_active: true)
  end

  test "handles AI service errors gracefully" do
    # Mock AI service that fails
    failing_service = Minitest::Mock.new
    failing_service.expect(:generate_content, proc { raise StandardError.new("AI service unavailable") })
    failing_service.expect(:ai_provider, nil)
    
    AiService.stub(:new, failing_service) do
      post "/api/v1/generate/social_media", params: {
        platform: "Instagram",
        brand_context: "Fashion brand"
      }, as: :json
      
      assert_response :internal_server_error
      
      json_response = JSON.parse(response.body)
      assert_not json_response["success"]
      assert json_response["error"].include?("Content generation failed")
    end
  end

  # Template system integration
  test "template variable extraction and rendering integration" do
    with_mocked_ai_service do
      # Disable existing social_media templates 
      PromptTemplate.where(prompt_type: 'social_media').update_all(is_active: false)
      
      # Create a custom template with specific variables
      custom_template = PromptTemplate.create!(
        name: "Integration Test Template",
        prompt_type: "social_media",
        system_prompt: "You are testing {{system_var}}.",
        user_prompt: "Create {{content_type}} for {{platform}} targeting {{target_audience}} with {{tone}} tone.",
        variables: [
          {"name" => "content_type", "type" => "string", "required" => false},
          {"name" => "platform", "type" => "string", "required" => true},
          {"name" => "target_audience", "type" => "string", "required" => false},  
          {"name" => "tone", "type" => "string", "required" => false}
        ],
        default_values: {"content_type" => "social media post", "tone" => "engaging"},
        is_active: true
      )
      
      post "/api/v1/generate/social_media", params: {
        platform: "Instagram",  # This satisfies the controller validation
        brand_context: "Test brand",  # This satisfies the controller validation
        target_audience: "millennials",
        content_type: "Instagram post"
        # tone not provided - should use default
      }, as: :json
      
      assert_response :success
      
      json_response = JSON.parse(response.body)
      assert json_response["success"]
      
      # Template usage should be incremented
      custom_template.reload
      assert custom_template.usage_count > 0
      
      # Cleanup
      custom_template.destroy
      # Re-enable any templates we disabled
      PromptTemplate.where(prompt_type: 'social_media').update_all(is_active: true)
    end
  end

  # Multiple endpoint workflow
  test "multiple content generation requests in sequence" do
    # Create a fresh mock for this test that allows multiple calls
    mock_ai_service = Minitest::Mock.new
    mock_response = {
      "content" => [{"text" => "This is generated content from the AI service"}]
    }
    
    # Allow multiple calls to generate_content
    3.times do
      mock_ai_service.expect(:generate_content, mock_response) do |user_prompt, **kwargs|
        user_prompt.is_a?(String) && kwargs.is_a?(Hash)
      end
      mock_ai_service.expect(:ai_provider, OpenStruct.new(model_name: "claude-3-5-sonnet-20241022"))
    end
    
    AiService.stub(:new, mock_ai_service) do
      
      # Generate social media content
      post "/api/v1/generate/social_media", params: {
        platform: "Instagram",
        brand_context: "Sustainable fashion brand"
      }, as: :json
      
      assert_response :success
      social_response = JSON.parse(response.body)
      assert social_response["success"]
      
      # Generate email content
      post "/api/v1/generate/email", params: {
        email_type: "newsletter",
        primary_goal: "engagement",
        brand_context: "Sustainable fashion brand"
      }, as: :json
      
      assert_response :success
      email_response = JSON.parse(response.body)
      assert email_response["success"]
      
      # Generate campaign plan
      post "/api/v1/generate/campaign_plan", params: {
        campaign_name: "Test Campaign",
        campaign_purpose: "Test integrated workflow"
      }, as: :json
      
      assert_response :success
      campaign_response = JSON.parse(response.body)
      assert campaign_response["success"]
      
      # Each should use different templates
      assert_not_equal social_response["template_used"], email_response["template_used"]
      assert_not_equal email_response["template_used"], campaign_response["template_used"]
    end
    
    # Verify all mock expectations were met
    mock_ai_service.verify
  end

  # Content type specific validation
  test "validates content-type specific requirements" do
    # Test ad copy specific validation
    post "/api/v1/generate/ad_copy", params: {
      brand_context: "Fashion brand"
      # Missing required 'offering' and 'target_audience' for ad copy
    }, as: :json
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert json_response["error"].include?("offering is required")
    assert json_response["error"].include?("target_audience is required")
    
    # Test landing page specific validation
    post "/api/v1/generate/landing_page", params: {
      brand_context: "Fashion brand"
      # Missing required 'page_purpose' and 'offering' for landing page
    }, as: :json
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert json_response["error"].include?("page_purpose is required")
    assert json_response["error"].include?("offering is required")
  end

  # Response format consistency
  test "response format consistency across endpoints" do
    # Create a fresh mock for this test
    mock_ai_service = Minitest::Mock.new
    mock_response = {
      "content" => [{"text" => "This is generated content from the AI service"}]
    }
    
    endpoints = [
      {path: "/api/v1/generate/social_media", params: {platform: "Instagram", brand_context: "Brand"}},
      {path: "/api/v1/generate/email", params: {email_type: "promotional", primary_goal: "conversion", brand_context: "Brand"}},
      {path: "/api/v1/generate/ad_copy", params: {offering: "Product", target_audience: "Users", brand_context: "Brand"}}
    ]
    
    # Set up expectations for each endpoint
    endpoints.length.times do
      mock_ai_service.expect(:generate_content, mock_response) do |user_prompt, **kwargs|
        user_prompt.is_a?(String) && kwargs.is_a?(Hash)
      end
      mock_ai_service.expect(:ai_provider, OpenStruct.new(model_name: "claude-3-5-sonnet-20241022"))
    end
    
    AiService.stub(:new, mock_ai_service) do
      endpoints.each do |endpoint|
        
        post endpoint[:path], params: endpoint[:params], as: :json
        
        assert_response :success, "#{endpoint[:path]} should succeed"
        
        json_response = JSON.parse(response.body)
        
        # Check consistent response structure
        assert json_response["success"], "Should have success field"
        assert json_response["content"], "Should have content field"
        assert json_response["template_used"], "Should have template_used field"
        assert json_response["generation_metadata"], "Should have generation_metadata field"
        
        # Check metadata structure
        metadata = json_response["generation_metadata"]
        %w[template_id template_version generated_at variable_count content_length].each do |field|
          assert metadata[field], "Metadata should include #{field}"
        end
      end
    end
    
    # Verify all mock expectations were met
    mock_ai_service.verify
  end

  private

  def teardown
    @mock_ai_service.verify if @mock_ai_service
  end
end