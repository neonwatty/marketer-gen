require "test_helper"
require "mocha/minitest"

class CampaignPlanServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @service = CampaignPlanService.new(@campaign_plan)
  end

  test "should generate plan successfully for valid campaign plan" do
    # Mock the LLM service response
    mock_response = {
      summary: "Comprehensive product launch campaign",
      strategy: {
        phases: ["Pre-launch", "Launch", "Post-launch"],
        channels: ["Social Media", "Email", "PR"],
        budget_allocation: { social: 40, email: 30, pr: 30 }
      },
      timeline: [
        { week: 1, activity: "Content creation" },
        { week: 2, activity: "Campaign launch" }
      ],
      assets: ["Social media graphics", "Email templates", "Press release"],
      metadata: { service: "mock", generated_at: Time.current }
    }

    # Mock the LLM service
    @service.stubs(:llm_service).returns(stub(generate_campaign_plan: mock_response))
    
    result = @service.generate_plan
    
    assert result[:success]
    assert_equal "Campaign plan generated successfully", result[:message]
    assert_equal @campaign_plan, result[:data]
    
    @campaign_plan.reload
    assert_equal "completed", @campaign_plan.status
    assert_equal "Comprehensive product launch campaign", @campaign_plan.generated_summary
    assert @campaign_plan.generated_strategy.is_a?(Hash)
    assert @campaign_plan.generated_timeline.is_a?(Array)
    assert @campaign_plan.generated_assets.is_a?(Array)
  end

  test "should fail if campaign plan is not in draft status" do
    @campaign_plan.update!(status: "completed")
    
    result = @service.generate_plan
    
    assert_not result[:success]
    assert_equal "Campaign plan must be in draft status", result[:message]
  end

  test "should fail if campaign plan is not ready for generation" do
    @campaign_plan.campaign_type = nil
    
    result = @service.generate_plan
    
    assert_not result[:success]
    assert_equal "Campaign plan is not ready for generation", result[:message]
  end

  test "should handle LLM service errors gracefully" do
    # Mock LLM service to raise an error
    mock_llm_service = stub('llm_service')
    mock_llm_service.stubs(:generate_campaign_plan).raises(StandardError.new("Service unavailable"))
    @service.stubs(:llm_service).returns(mock_llm_service)
    
    result = @service.generate_plan
    
    assert_not result[:success]
    assert_includes result[:message], "Failed to generate campaign plan"
    assert_includes result[:message], "Service unavailable"
    
    @campaign_plan.reload
    assert_equal "failed", @campaign_plan.status
    assert_equal "Service unavailable", @campaign_plan.metadata["error_message"]
  end

  test "should mark generation as started when beginning generation" do
    # Mock the LLM service to avoid actual generation
    @service.stubs(:llm_service).returns(stub(generate_campaign_plan: {
      summary: "Test summary",
      strategy: {},
      timeline: [],
      assets: []
    }))
    
    travel_to Time.zone.parse("2025-01-15 10:00:00") do
      @service.generate_plan
      
      @campaign_plan.reload
      assert_not_nil @campaign_plan.metadata["generation_started_at"]
    end
  end

  test "should gather brand context from user's active brand identity" do
    # Create a brand identity for the user
    brand_identity = brand_identities(:active_brand)
    brand_identity.update!(user: @user, is_active: true)
    
    # Mock LLM service to capture the parameters
    captured_params = nil
    mock_llm_service = stub('llm_service')
    mock_llm_service.stubs(:generate_campaign_plan).with do |params|
      captured_params = params
      true
    end.returns({summary: "Test"})
    
    @service.stubs(:llm_service).returns(mock_llm_service)
    @service.generate_plan
    
    assert_not_nil captured_params
    brand_context = captured_params[:brand_context]
    assert_equal brand_identity.name, brand_context[:brand_name]
    assert_equal brand_identity.brand_voice, brand_context[:brand_voice]
  end

  test "should include campaign-specific brand context" do
    @campaign_plan.update!(brand_context: '{"custom_voice": "energetic", "restrictions": "no competitor mentions"}')
    
    # Mock LLM service to capture the parameters
    captured_params = nil
    mock_llm_service = stub('llm_service')
    mock_llm_service.stubs(:generate_campaign_plan).with do |params|
      captured_params = params
      true
    end.returns({summary: "Test"})
    
    @service.stubs(:llm_service).returns(mock_llm_service)
    @service.generate_plan
    
    assert_not_nil captured_params
    brand_context = captured_params[:brand_context]
    assert_equal "energetic", brand_context["custom_voice"]
    assert_equal "no competitor mentions", brand_context["restrictions"]
  end

  test "should prepare comprehensive LLM parameters" do
    @campaign_plan.update!(
      target_audience: "Tech professionals",
      budget_constraints: "Budget: $10,000",
      timeline_constraints: "3 months"
    )
    
    # Mock LLM service to capture the parameters
    captured_params = nil
    mock_llm_service = stub('llm_service')
    mock_llm_service.stubs(:generate_campaign_plan).with do |params|
      captured_params = params
      true
    end.returns({summary: "Test"})
    
    @service.stubs(:llm_service).returns(mock_llm_service)
    @service.generate_plan
    
    assert_not_nil captured_params
    assert_equal @campaign_plan.campaign_type, captured_params[:campaign_type]
    assert_equal @campaign_plan.objective, captured_params[:objective]
    assert_equal @campaign_plan.description, captured_params[:description]
    assert_not_nil captured_params[:brand_context]
    assert_not_nil captured_params[:user_context]
  end

  test "regenerate_plan should reset and regenerate campaign plan" do
    # Set up a completed campaign plan
    completed_plan = campaign_plans(:completed_plan)
    service = CampaignPlanService.new(completed_plan)
    
    # Store original generated content
    original_summary = completed_plan.generated_summary
    
    # Mock LLM service for regeneration
    service.stubs(:llm_service).returns(stub(generate_campaign_plan: {
      summary: "New regenerated summary",
      strategy: {},
      timeline: [],
      assets: []
    }))
    
    result = service.regenerate_plan
    
    assert result[:success]
    
    completed_plan.reload
    assert_equal "completed", completed_plan.status
    assert_equal "New regenerated summary", completed_plan.generated_summary
    assert_not_equal original_summary, completed_plan.generated_summary
    assert_not_nil completed_plan.metadata["regenerated_at"]
  end

  test "regenerate_plan should fail for non-regeneratable plans" do
    draft_plan = campaign_plans(:draft_plan)
    service = CampaignPlanService.new(draft_plan)
    
    result = service.regenerate_plan
    
    assert_not result[:success]
    assert_equal "Campaign plan cannot be regenerated", result[:message]
  end

  test "update_plan_parameters should update allowed parameters" do
    new_params = {
      name: "Updated Campaign Name",
      description: "Updated description",
      campaign_type: "brand_awareness",
      objective: "customer_acquisition",
      target_audience: "Updated audience",
      brand_context: "Updated context",
      budget_constraints: "Updated budget",
      timeline_constraints: "Updated timeline"
    }
    
    result = @service.update_plan_parameters(new_params)
    
    assert result[:success]
    assert_equal "Campaign plan parameters updated", result[:message]
    
    @campaign_plan.reload
    assert_equal "Updated Campaign Name", @campaign_plan.name
    assert_equal "Updated description", @campaign_plan.description
    assert_equal "brand_awareness", @campaign_plan.campaign_type
    assert_equal "customer_acquisition", @campaign_plan.objective
  end

  test "update_plan_parameters should reject invalid parameters" do
    invalid_params = {
      name: "", # Required field
      campaign_type: "invalid_type"
    }
    
    result = @service.update_plan_parameters(invalid_params)
    
    assert_not result[:success]
    assert_includes result[:message], "Invalid parameters"
  end

  test "update_plan_parameters should not allow updating status or generated content" do
    malicious_params = {
      name: "Updated Name",
      status: "completed", # Should not be allowed
      generated_summary: "Hacked content", # Should not be allowed
      user_id: users(:team_member_user).id # Should not be allowed
    }
    
    original_status = @campaign_plan.status
    original_user_id = @campaign_plan.user_id
    
    result = @service.update_plan_parameters(malicious_params)
    
    assert result[:success] # Should succeed but ignore disallowed params
    
    @campaign_plan.reload
    assert_equal "Updated Name", @campaign_plan.name
    assert_equal original_status, @campaign_plan.status # Should not change
    assert_nil @campaign_plan.generated_summary # Should not change
    assert_equal original_user_id, @campaign_plan.user_id # Should not change
  end

  test "should extract industry from brand context" do
    # Test technology industry detection
    brand_context = { "description" => "We are a tech startup building software solutions" }
    industry = @service.send(:extract_industry_from_brand_context, brand_context)
    assert_equal "technology", industry
    
    # Test healthcare industry detection
    brand_context = { "company" => "HealthCare Medical Solutions" }
    industry = @service.send(:extract_industry_from_brand_context, brand_context)
    assert_equal "healthcare", industry
    
    # Test default when no industry keywords found
    brand_context = { "description" => "We provide unique business solutions" }
    industry = @service.send(:extract_industry_from_brand_context, brand_context)
    assert_equal "general", industry
  end

  test "should process various LLM response formats" do
    # Test with symbol keys
    response_with_symbols = {
      summary: "Test summary",
      strategy: { phases: ["Phase 1"] },
      timeline: [{ week: 1, activity: "Test activity" }],
      assets: ["Asset 1"]
    }
    
    @service.stubs(:llm_service).returns(stub(generate_campaign_plan: response_with_symbols))
    
    result = @service.generate_plan
    assert result[:success]
    
    @campaign_plan.reload
    assert_equal "Test summary", @campaign_plan.generated_summary
    
    # Reset campaign plan for next test
    @campaign_plan.update!(status: "draft", generated_summary: nil)
    
    # Test with string keys
    response_with_strings = {
      "summary" => "Test summary 2",
      "strategy" => { "phases" => ["Phase 2"] },
      "timeline" => [{ "week" => 2, "activity" => "Test activity 2" }],
      "assets" => ["Asset 2"]
    }
    
    @service.stubs(:llm_service).returns(stub(generate_campaign_plan: response_with_strings))
    
    result = @service.generate_plan
    assert result[:success]
    
    @campaign_plan.reload
    assert_equal "Test summary 2", @campaign_plan.generated_summary
  end

  test "should handle non-hash/array responses gracefully" do
    response_with_strings = {
      summary: "String summary",
      strategy: "String strategy", # Not a hash
      timeline: "String timeline", # Not an array
      assets: "String assets" # Not an array
    }
    
    @service.stubs(:llm_service).returns(stub(generate_campaign_plan: response_with_strings))
    
    result = @service.generate_plan
    assert result[:success]
    
    @campaign_plan.reload
    assert_equal "String summary", @campaign_plan.generated_summary
    assert_equal({ "description" => "String strategy" }, @campaign_plan.generated_strategy)
    assert_equal([{ "activity" => "String timeline" }], @campaign_plan.generated_timeline)
    assert_equal(["String assets"], @campaign_plan.generated_assets)
  end
end