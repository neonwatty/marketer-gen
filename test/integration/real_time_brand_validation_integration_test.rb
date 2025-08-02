require 'test_helper'
require 'webmock/minitest'

class RealTimeBrandValidationIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @user = users(:one)
    @brand = brands(:one)
    @messaging_framework = messaging_frameworks(:professional_tech)
    sign_in_as(@user)
    
    # Setup WebSocket connection mocking
    setup_websocket_mocks
    
    # Setup real-time brand validation service mocks
    setup_real_time_validation_mocks
  end

  def teardown
    WebMock.reset!
  end

  # Test real-time content validation with immediate feedback
  test "should provide immediate brand compliance feedback during content creation" do
    # Start a real-time validation session
    post "/api/v1/llm_integration/real_time_validation/start_session",
         params: {
           brand_id: @brand.id,
           validation_mode: "strict",
           feedback_granularity: "character_level"
         },
         as: :json

    assert_response :created
    session_data = JSON.parse(response.body)
    session_id = session_data["session_id"]
    websocket_token = session_data["websocket_token"]
    
    # Simulate real-time content input and validation
    content_stream = [
      { text: "Our", expected_status: "neutral" },
      { text: " professional", expected_status: "positive" },
      { text: " analytics", expected_status: "positive" },
      { text: " platform", expected_status: "positive" },
      { text: " is AMAZING!!!", expected_status: "violation" },
      { text: " delivers", expected_status: "corrective" },
      { text: " comprehensive", expected_status: "positive" },
      { text: " business insights", expected_status: "positive" }
    ]

    content_stream.each_with_index do |content_chunk, index|
      # Send content chunk for real-time validation
      post "/api/v1/llm_integration/real_time_validation/#{session_id}/validate_chunk",
           params: {
             text_chunk: content_chunk[:text],
             chunk_position: index,
             websocket_token: websocket_token
           },
           as: :json

      assert_response :success
      chunk_response = JSON.parse(response.body)
      
      # Verify real-time validation response
      assert_includes chunk_response.keys, "validation_status"
      assert_includes chunk_response.keys, "compliance_impact"
      assert_includes chunk_response.keys, "suggestions"
      
      case content_chunk[:expected_status]
      when "positive"
        assert_equal "enhances_compliance", chunk_response["validation_status"]
        assert chunk_response["compliance_impact"] > 0
      when "violation"
        assert_equal "compliance_violation", chunk_response["validation_status"]
        assert chunk_response["compliance_impact"] < 0
        assert_not_empty chunk_response["suggestions"]
      when "corrective"
        assert_equal "corrects_previous_violation", chunk_response["validation_status"]
      end
      
      # Verify immediate suggestions are provided when needed
      if chunk_response["validation_status"] == "compliance_violation"
        suggestions = chunk_response["suggestions"]
        assert_not_empty suggestions
        assert_includes suggestions.first.keys, "replacement_text"
        assert_includes suggestions.first.keys, "improvement_reason"
        assert_includes suggestions.first.keys, "compliance_improvement"
      end
    end

    # Get final validation summary
    get "/api/v1/llm_integration/real_time_validation/#{session_id}/summary"
    assert_response :success
    
    summary = JSON.parse(response.body)
    assert_includes summary.keys, "overall_compliance_score"
    assert_includes summary.keys, "validation_timeline"
    assert_includes summary.keys, "improvement_suggestions"
    assert summary["total_chunks_validated"] == content_stream.length
  end

  # Test WebSocket-based real-time brand compliance monitoring
  test "should provide WebSocket-based real-time compliance monitoring for collaborative editing" do
    # Initialize WebSocket connection for real-time monitoring
    post "/api/v1/llm_integration/brand_compliance/websocket/initialize",
         params: {
           brand_id: @brand.id,
           monitoring_sensitivity: "high",
           collaborative_session: true
         },
         as: :json

    assert_response :created
    websocket_data = JSON.parse(response.body)
    connection_token = websocket_data["connection_token"]
    channel_name = websocket_data["channel_name"]
    
    # Simulate collaborative editing session with multiple users
    collaboration_events = [
      {
        event_type: "content_added",
        user_id: @user.id,
        content: "Our enterprise solution",
        position: 0,
        timestamp: Time.current.to_i
      },
      {
        event_type: "content_modified",
        user_id: users(:two).id,
        content: "Our REVOLUTIONARY enterprise solution",
        position: 0,
        timestamp: (Time.current + 1.second).to_i
      },
      {
        event_type: "content_added",
        user_id: @user.id,
        content: " provides comprehensive analytics capabilities",
        position: 30,
        timestamp: (Time.current + 2.seconds).to_i
      }
    ]

    collaboration_events.each do |event|
      # Send collaboration event for real-time monitoring
      post "/api/v1/llm_integration/brand_compliance/websocket/monitor_event",
           params: {
             connection_token: connection_token,
             event_data: event
           },
           as: :json

      assert_response :success
      monitoring_response = JSON.parse(response.body)
      
      # Verify real-time compliance monitoring
      assert_includes monitoring_response.keys, "compliance_alert"
      assert_includes monitoring_response.keys, "real_time_score"
      assert_includes monitoring_response.keys, "broadcast_required"
      
      # Check for compliance violations in real-time
      if event[:content].include?("REVOLUTIONARY")
        assert monitoring_response["compliance_alert"]
        assert monitoring_response["alert_severity"] == "medium"
        assert_not_empty monitoring_response["alert_message"]
        assert monitoring_response["broadcast_required"]
        
        # Verify suggestion for improvement
        assert_includes monitoring_response, "suggested_correction"
        assert monitoring_response["suggested_correction"]["original"] == "REVOLUTIONARY"
        assert_not_equal monitoring_response["suggested_correction"]["suggested"], "REVOLUTIONARY"
      end
    end

    # Test real-time compliance trend monitoring
    get "/api/v1/llm_integration/brand_compliance/websocket/#{connection_token}/compliance_trends"
    assert_response :success
    
    trends = JSON.parse(response.body)
    assert_includes trends.keys, "compliance_timeline"
    assert_includes trends.keys, "trend_direction"
    assert_includes trends.keys, "prediction"
    assert trends["data_points"].length == collaboration_events.length
  end

  # Test automated content correction with real-time brand validation
  test "should provide automated content correction suggestions in real-time during content creation" do
    # Start auto-correction enabled validation session
    post "/api/v1/llm_integration/real_time_validation/start_autocorrect_session",
         params: {
           brand_id: @brand.id,
           auto_correction_level: "aggressive",
           learning_enabled: true,
           preserve_user_intent: true
         },
         as: :json

    assert_response :created
    autocorrect_data = JSON.parse(response.body)
    session_id = autocorrect_data["session_id"]
    
    # Test various content scenarios requiring correction
    test_scenarios = [
      {
        input_content: "This AMAZING product will BLOW YOUR MIND!!!",
        expected_corrections: ["tone_adjustment", "exclamation_reduction", "professional_language"],
        description: "Over-enthusiastic marketing language"
      },
      {
        input_content: "We have a thing that might help you somewhat maybe.",
        expected_corrections: ["confidence_enhancement", "specificity_improvement", "value_clarification"],
        description: "Weak and uncertain language"
      },
      {
        input_content: "Our cheap solution is better than competitors who charge more.",
        expected_corrections: ["value_positioning", "competitive_language", "brand_tone_alignment"],
        description: "Problematic competitive positioning"
      },
      {
        input_content: "Contact us for more information if you want.",
        expected_corrections: ["call_to_action_strength", "engagement_improvement"],
        description: "Weak call-to-action"
      }
    ]

    test_scenarios.each_with_index do |scenario, index|
      # Submit content for real-time auto-correction
      post "/api/v1/llm_integration/real_time_validation/#{session_id}/autocorrect",
           params: {
             content: scenario[:input_content],
             scenario_id: "test_#{index}",
             correction_preferences: {
               maintain_length: false,
               preserve_key_terms: true,
               brand_alignment_priority: "high"
             }
           },
           as: :json

      assert_response :success
      correction_response = JSON.parse(response.body)
      
      # Verify auto-correction response structure
      assert_includes correction_response.keys, "original_content"
      assert_includes correction_response.keys, "corrected_content"
      assert_includes correction_response.keys, "corrections_applied"
      assert_includes correction_response.keys, "improvement_score"
      assert_includes correction_response.keys, "brand_compliance_improvement"
      
      # Verify content was actually corrected
      refute_equal scenario[:input_content], correction_response["corrected_content"]
      
      # Verify expected correction types were applied
      applied_corrections = correction_response["corrections_applied"].map { |c| c["correction_type"] }
      scenario[:expected_corrections].each do |expected_correction|
        assert_includes applied_corrections, expected_correction, 
               "Expected correction '#{expected_correction}' not found for scenario: #{scenario[:description]}"
      end
      
      # Verify brand compliance improved
      assert correction_response["brand_compliance_improvement"] > 0.1,
             "Brand compliance should improve significantly for scenario: #{scenario[:description]}"
      
      # Verify specific improvements
      corrections_applied = correction_response["corrections_applied"]
      corrections_applied.each do |correction|
        assert_includes correction.keys, "before_text"
        assert_includes correction.keys, "after_text"
        assert_includes correction.keys, "improvement_reason"
        assert_includes correction.keys, "brand_alignment_score"
        assert correction["brand_alignment_score"] > 0.7
      end
    end

    # Test learning from correction patterns
    get "/api/v1/llm_integration/real_time_validation/#{session_id}/learning_insights"
    assert_response :success
    
    learning_data = JSON.parse(response.body)
    assert_includes learning_data.keys, "common_correction_patterns"
    assert_includes learning_data.keys, "user_acceptance_rate"
    assert_includes learning_data.keys, "brand_improvement_trends"
    assert learning_data["total_corrections_analyzed"] >= test_scenarios.length
  end

  # Test integration with content creation workflows
  test "should integrate real-time brand validation with existing content creation workflows" do
    # Test integration with journey builder
    journey = journeys(:onboarding_sequence)
    journey_step = journey_steps(:welcome_email)
    
    # Start real-time validation for journey content creation
    post "/api/v1/journeys/#{journey.id}/steps/#{journey_step.id}/start_realtime_validation",
         params: {
           brand_id: @brand.id,
           validation_scope: "step_content",
           integration_mode: "embedded"
         },
         as: :json

    assert_response :success
    journey_validation = JSON.parse(response.body)
    validation_session_id = journey_validation["validation_session_id"]
    
    # Update journey step content with real-time validation
    patch "/api/v1/journeys/#{journey.id}/steps/#{journey_step.id}",
          params: {
            content: "Welcome to our professional analytics platform",
            validation_session_id: validation_session_id,
            real_time_validation: true
          },
          as: :json

    assert_response :success
    update_response = JSON.parse(response.body)
    
    # Verify real-time validation was applied
    assert update_response["real_time_validation_applied"]
    assert update_response["brand_compliance_score"] >= 0.85
    assert_includes update_response, "validation_feedback"
    
    # Test integration with messaging framework editor
    messaging_framework = messaging_frameworks(:professional_tech)
    
    post "/api/v1/messaging_frameworks/#{messaging_framework.id}/start_realtime_validation",
         params: {
           brand_id: @brand.id,
           validation_focus: "messaging_principles",
           real_time_suggestions: true
         },
         as: :json

    assert_response :success
    framework_validation = JSON.parse(response.body)
    
    # Update messaging pillar with real-time validation
    patch "/api/v1/messaging_frameworks/#{messaging_framework.id}",
          params: {
            messaging_principles: [
              "Data-driven business intelligence",
              "Enterprise-grade security and reliability", 
              "Seamless integration capabilities"
            ],
            validation_session_id: framework_validation["validation_session_id"]
          },
          as: :json

    assert_response :success
    framework_update = JSON.parse(response.body)
    
    # Verify messaging framework validation
    assert framework_update["messaging_alignment_validated"]
    assert framework_update["pillar_consistency_score"] >= 0.90
    assert_not_empty framework_update["cross_pillar_analysis"]
  end

  # Test performance and scalability of real-time validation
  test "should handle high-frequency real-time validation requests efficiently" do
    # Setup performance monitoring
    start_time = Time.current
    
    # Create multiple concurrent validation sessions
    session_ids = []
    5.times do |i|
      post "/api/v1/llm_integration/real_time_validation/start_session",
           params: {
             brand_id: @brand.id,
             session_name: "performance_test_#{i}",
             validation_mode: "fast"
           },
           as: :json

      assert_response :created
      session_data = JSON.parse(response.body)
      session_ids << session_data["session_id"]
    end

    # Send high-frequency validation requests
    validation_requests = 0
    successful_validations = 0
    
    50.times do |request_index|
      session_id = session_ids[request_index % session_ids.length]
      
      post "/api/v1/llm_integration/real_time_validation/#{session_id}/validate_chunk",
           params: {
             text_chunk: "Our professional analytics solution #{request_index}",
             chunk_position: request_index,
             performance_test: true
           },
           as: :json
      
      validation_requests += 1
      
      if response.status == 200
        successful_validations += 1
        response_data = JSON.parse(response.body)
        assert_includes response_data.keys, "validation_status"
        assert response_data["processing_time_ms"] < 100 # Should be fast
      end
    end

    total_time = Time.current - start_time
    
    # Performance assertions
    assert successful_validations >= 45, "Should successfully handle at least 90% of validation requests"
    assert total_time < 10.seconds, "Should complete 50 validations in under 10 seconds"
    
    # Verify no memory leaks or resource issues
    session_ids.each do |session_id|
      get "/api/v1/llm_integration/real_time_validation/#{session_id}/resource_usage"
      assert_response :success
      
      resource_data = JSON.parse(response.body)
      assert resource_data["memory_usage_mb"] < 50
      assert resource_data["connection_status"] == "healthy"
    end
  end

  private

  def setup_websocket_mocks
    # Mock WebSocket connection establishment
    allow_any_instance_of(ActionCable::Connection::Base).to receive(:websocket).and_return(
      double("websocket", close: true, send: true)
    )
  end

  def setup_real_time_validation_mocks
    # Mock real-time brand compliance checking
    allow_any_instance_of(LlmIntegration::RealTimeBrandValidator).to receive(:validate_chunk).and_return(
      {
        validation_status: "compliance_check_passed",
        compliance_impact: 0.05,
        suggestions: [],
        processing_time_ms: 25
      }
    )
    
    # Mock auto-correction service
    allow_any_instance_of(LlmIntegration::AutoCorrectionService).to receive(:correct_content).and_return(
      {
        corrected_content: "Our professional analytics platform delivers comprehensive business insights",
        corrections_applied: [
          {
            correction_type: "tone_adjustment",
            before_text: "AMAZING",
            after_text: "professional",
            improvement_reason: "Maintains professional brand tone",
            brand_alignment_score: 0.95
          }
        ],
        improvement_score: 0.3,
        brand_compliance_improvement: 0.25
      }
    )
  end

  def sign_in_as(user)
    post "/sessions", params: {
      email_address: user.email_address,
      password: "password"
    }
  end
end