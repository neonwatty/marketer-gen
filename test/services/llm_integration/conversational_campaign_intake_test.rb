require 'test_helper'

class ConversationalCampaignIntakeTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @brand = brands(:one)
    # @conversation_service = LlmIntegration::ConversationalCampaignService.new(@user, @brand)
    # @nlp_processor = LlmIntegration::CampaignNLPProcessor.new
    # @workflow_engine = LlmIntegration::ConversationalWorkflowEngine.new
  end

  test "should support natural language campaign setup" do
    # Test natural language processing of campaign requirements
    user_input = "I want to launch a product announcement campaign for our new AI tool targeting B2B customers with a budget of $10,000"
    
    parsed_requirements = @nlp_processor.parse_campaign_intent(user_input)
    
    assert_equal "product_announcement", parsed_requirements[:campaign_type]
    assert_equal "AI tool", parsed_requirements[:product_name]
    assert_equal "B2B customers", parsed_requirements[:target_audience]
    assert_equal 10000, parsed_requirements[:budget]
    assert_includes parsed_requirements[:extracted_entities], "launch"
    assert_includes parsed_requirements[:extracted_entities], "announcement"
  end

  test "should reduce campaign setup time by 70%" do
    # Test conversation-driven setup vs traditional form-based setup
    conversation_start_time = Time.current
    
    conversation_flow = @conversation_service.start_conversation
    assert_not_nil conversation_flow.session_id
    assert_equal :campaign_setup, conversation_flow.intent
    
    # Simulate rapid conversation-based setup
    conversation_steps = [
      "I need a email marketing campaign for our product launch",
      "Target audience is enterprise customers in tech industry", 
      "Budget is around $15,000",
      "Timeline is 6 weeks starting next month",
      "Goal is to generate 500 qualified leads"
    ]
    
    conversation_steps.each_with_index do |step, index|
      response = @conversation_service.process_message(step)
      assert response[:understood]
      assert_not_empty response[:extracted_info]
      assert_not_empty response[:next_questions] if index < conversation_steps.length - 1
    end
    
    campaign_setup = @conversation_service.generate_campaign_plan
    
    # Should have comprehensive campaign setup
    assert_not_nil campaign_setup[:campaign_name]
    assert_not_nil campaign_setup[:target_audience]
    assert_not_nil campaign_setup[:budget_allocation]
    assert_not_nil campaign_setup[:timeline]
    assert_not_nil campaign_setup[:success_metrics]
    
    setup_time = Time.current - conversation_start_time
    
    # Record for baseline comparison
    @conversation_service.record_setup_metrics(
      conversation_time: setup_time,
      steps_completed: conversation_steps.length,
      user_satisfaction: :high
    )
    
    # Should indicate significant time savings
    efficiency_score = @conversation_service.calculate_efficiency_score
    assert efficiency_score[:time_savings_percentage] >= 70
  end

  test "should maintain conversation context across sessions" do
    # Test session persistence and context management
    session_manager = LlmIntegration::ConversationSessionManager.new(@user)
    
    # Start conversation
    session = session_manager.create_session(@brand)
    session_id = session.id
    
    # Add context from first interaction
    context_data = {
      campaign_type: "product_launch",
      discussed_topics: ["target_audience", "budget"],
      user_preferences: { communication_style: "detailed" }
    }
    
    session_manager.update_context(session_id, context_data)
    
    # Simulate session break and resume
    retrieved_session = session_manager.resume_session(session_id)
    
    assert_equal "product_launch", retrieved_session.context[:campaign_type]
    assert_includes retrieved_session.context[:discussed_topics], "target_audience"
    assert_equal "detailed", retrieved_session.context[:user_preferences][:communication_style]
    
    # Test context-aware responses
    contextual_response = @conversation_service.generate_contextual_response(
      "What about the timeline?",
      session_context: retrieved_session.context
    )
    
    assert_includes contextual_response[:message], "product launch timeline"
    assert contextual_response[:references_previous_context]
  end

  test "should provide intelligent campaign parameter suggestions" do
    suggestion_engine = LlmIntegration::CampaignSuggestionEngine.new(@brand)
    
    # Test suggestion based on partial information
    partial_campaign_info = {
      industry: "technology",
      company_size: "enterprise",
      campaign_goal: "lead_generation"
    }
    
    suggestions = suggestion_engine.suggest_campaign_parameters(partial_campaign_info)
    
    assert_not_nil suggestions[:recommended_channels]
    assert_includes suggestions[:recommended_channels], "linkedin"
    assert_includes suggestions[:recommended_channels], "email"
    
    assert_not_nil suggestions[:budget_recommendations]
    assert suggestions[:budget_recommendations][:min_effective_budget] > 0
    
    assert_not_nil suggestions[:timeline_suggestions]
    assert suggestions[:timeline_suggestions][:recommended_duration_weeks] >= 4
    
    assert_not_nil suggestions[:audience_targeting]
    assert_includes suggestions[:audience_targeting][:job_titles], "CTO"
  end

  test "should validate user input and handle errors gracefully" do
    input_validator = LlmIntegration::ConversationInputValidator.new
    
    # Test valid input
    valid_input = "I want to create an email campaign with a $5000 budget"
    validation = input_validator.validate(valid_input)
    
    assert validation[:valid]
    assert_empty validation[:errors]
    assert_not_empty validation[:extracted_entities]
    
    # Test invalid/incomplete input
    invalid_input = "umm... maybe something about marketing?"
    validation = input_validator.validate(invalid_input)
    
    refute validation[:valid]
    assert_includes validation[:errors], "insufficient_information"
    assert_not_empty validation[:clarification_questions]
    
    # Test error recovery
    clarifying_response = @conversation_service.handle_unclear_input(invalid_input)
    assert_includes clarifying_response[:message], "help me understand"
    assert_not_empty clarifying_response[:suggested_prompts]
  end

  test "should support multi-turn conversation flow with branching logic" do
    flow_engine = LlmIntegration::ConversationalFlowEngine.new
    
    # Define conversation flow
    flow_definition = {
      start: :campaign_type_identification,
      states: {
        campaign_type_identification: {
          prompt: "What type of campaign would you like to create?",
          next_states: {
            "product_launch" => :product_launch_flow,
            "lead_generation" => :lead_gen_flow,
            "brand_awareness" => :awareness_flow
          }
        },
        product_launch_flow: {
          prompt: "Tell me about the product you're launching",
          required_info: [:product_name, :launch_date, :target_market],
          next_states: { "complete" => :budget_planning }
        }
      }
    }
    
    flow_instance = flow_engine.create_flow(flow_definition)
    
    # Test flow navigation
    current_state = flow_instance.current_state
    assert_equal :campaign_type_identification, current_state[:name]
    
    # Process user response
    user_response = "I want to launch a new product"
    next_state = flow_instance.process_response(user_response)
    
    assert_equal :product_launch_flow, next_state[:name]
    assert_includes next_state[:required_info], :product_name
  end

  test "should integrate with journey builder workflow" do
    journey_integration = LlmIntegration::JourneyBuilderIntegration.new
    
    # Test conversion from conversation to journey
    conversation_summary = {
      campaign_type: "nurture_sequence",
      target_audience: "trial_users",
      touchpoints: ["welcome_email", "feature_tutorial", "upgrade_prompt"],
      timeline: "14_days"
    }
    
    journey_draft = journey_integration.convert_to_journey(conversation_summary)
    
    assert_not_nil journey_draft[:journey_steps]
    assert_equal 3, journey_draft[:journey_steps].length
    
    assert_equal "welcome_email", journey_draft[:journey_steps][0][:type]
    assert_equal "feature_tutorial", journey_draft[:journey_steps][1][:type]
    assert_equal "upgrade_prompt", journey_draft[:journey_steps][2][:type]
    
    # Test journey validation
    validation_result = journey_integration.validate_journey_draft(journey_draft)
    assert validation_result[:valid]
    assert_empty validation_result[:errors]
  end

  test "should provide real-time campaign cost estimation" do
    cost_estimator = LlmIntegration::RealTimeCostEstimator.new
    
    campaign_params = {
      channels: ["email", "linkedin", "google_ads"],
      target_audience_size: 10000,
      campaign_duration_weeks: 6,
      content_pieces_needed: 15
    }
    
    cost_estimate = cost_estimator.calculate_estimate(campaign_params)
    
    assert_not_nil cost_estimate[:total_estimated_cost]
    assert cost_estimate[:total_estimated_cost] > 0
    
    assert_not_nil cost_estimate[:breakdown]
    assert_includes cost_estimate[:breakdown].keys, :email_costs
    assert_includes cost_estimate[:breakdown].keys, :linkedin_costs
    assert_includes cost_estimate[:breakdown].keys, :google_ads_costs
    assert_includes cost_estimate[:breakdown].keys, :content_creation_costs
    
    # Test cost optimization suggestions
    assert_not_nil cost_estimate[:optimization_suggestions]
    assert cost_estimate[:optimization_suggestions].length > 0
  end

  test "should handle conversation interruptions and resumption" do
    interruption_handler = LlmIntegration::ConversationInterruptionHandler.new
    
    # Simulate conversation interruption
    active_conversation = @conversation_service.start_conversation
    conversation_id = active_conversation.session_id
    
    # Add some conversation history
    @conversation_service.process_message("I want to create an email campaign")
    @conversation_service.process_message("Target audience is small businesses")
    
    # Simulate interruption (user leaves, session timeout, etc.)
    interruption_handler.handle_interruption(conversation_id, reason: :user_timeout)
    
    # Test resumption
    resumed_conversation = interruption_handler.resume_conversation(conversation_id, @user)
    
    assert_not_nil resumed_conversation
    assert_equal conversation_id, resumed_conversation.session_id
    assert resumed_conversation.context[:previously_discussed].include?("email campaign")
    
    # Test resumption message
    resumption_message = resumed_conversation.generate_resumption_message
    assert_includes resumption_message, "continue where we left off"
    assert_includes resumption_message, "email campaign"
  end

  test "should learn from conversation patterns and improve" do
    learning_system = LlmIntegration::ConversationLearningSystem.new
    
    # Record successful conversation patterns
    successful_pattern = {
      conversation_flow: ["greeting", "campaign_type", "audience", "budget", "timeline", "confirmation"],
      user_satisfaction: 9,
      completion_rate: 100,
      setup_time_minutes: 8
    }
    
    learning_system.record_conversation_outcome(successful_pattern)
    
    # Record unsuccessful pattern
    unsuccessful_pattern = {
      conversation_flow: ["greeting", "complex_question", "user_confusion", "abandonment"],
      user_satisfaction: 3,
      completion_rate: 30,
      setup_time_minutes: 15
    }
    
    learning_system.record_conversation_outcome(unsuccessful_pattern)
    
    # Test pattern recognition and improvement
    improved_flow = learning_system.suggest_improved_flow
    
    assert_includes improved_flow[:recommended_early_questions], "campaign_type"
    assert_includes improved_flow[:patterns_to_avoid], "complex_question"
    assert improved_flow[:expected_satisfaction_improvement] > 0
  end

  test "should support multiple languages and localization" do
    multilingual_service = LlmIntegration::MultilingualConversationService.new
    
    # Test language detection
    spanish_input = "Quiero crear una campaña de marketing por email"
    detected_language = multilingual_service.detect_language(spanish_input)
    assert_equal "es", detected_language[:code]
    assert detected_language[:confidence] > 0.9
    
    # Test localized responses
    localized_response = multilingual_service.generate_response(
      spanish_input,
      language: "es",
      context: { campaign_setup: true }
    )
    
    assert_includes localized_response[:message], "campaña"
    assert_equal "es", localized_response[:language]
    
    # Test campaign parameter localization
    localized_suggestions = multilingual_service.localize_campaign_suggestions(
      {
        channels: ["email", "social_media"],
        budget_range: [1000, 5000]
      },
      language: "es",
      region: "MX"
    )
    
    assert_includes localized_suggestions[:channels], "correo_electronico"
    assert_equal "MXN", localized_suggestions[:currency]
  end
end