# frozen_string_literal: true

require 'test_helper'

class CampaignIntakeServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @mock_llm_service = MockLlmService.new
    @service = CampaignIntakeService.new(user: @user)
    
    # Mock the LLM service
    @service.stubs(:llm_service).returns(@mock_llm_service)
  end

  test "should initialize with default values" do
    service = CampaignIntakeService.new(user: @user)
    
    assert_equal @user, service.instance_variable_get(:@user)
    assert_equal 'initial', service.instance_variable_get(:@current_state)
    assert_equal({}, service.instance_variable_get(:@extracted_parameters))
    assert_equal([], service.instance_variable_get(:@conversation_history))
    assert_equal 0, service.instance_variable_get(:@question_count)
  end

  test "should initialize with existing conversation data" do
    conversation_data = {
      state: 'gathering_basics',
      extracted_parameters: { 'campaign_type' => 'awareness' },
      conversation_history: [{ type: 'ai_question', content: 'Hello!' }],
      question_count: 1
    }
    
    service = CampaignIntakeService.new(user: @user, conversation_data: conversation_data)
    
    assert_equal 'gathering_basics', service.instance_variable_get(:@current_state)
    assert_equal({ 'campaign_type' => 'awareness' }, service.instance_variable_get(:@extracted_parameters))
    assert_equal 1, service.instance_variable_get(:@question_count)
  end

  test "should generate initial question for new conversation" do
    result = @service.call
    
    assert result[:success]
    assert_not_nil result[:data][:question]
    assert_equal 'initial', result[:data][:conversation_state]
    assert_equal 1, result[:data][:progress][:question_count]
    assert result[:data][:question].length > 10 # Just check we get a meaningful question
  end

  test "should process user response and extract parameters" do
    # Mock LLM response for parameter extraction
    @mock_llm_service.stubs(:generate_analytics_insights).returns({
      insights: ['{"campaign_type": "awareness", "primary_objective": "increase brand visibility"}']
    })
    
    # Mock LLM response for question generation
    @mock_llm_service.stubs(:generate_campaign_plan).returns({
      summary: "Who is your target audience for this awareness campaign?"
    })

    service = CampaignIntakeService.new(
      user: @user,
      user_response: "I want to increase brand visibility for our new product launch"
    )
    service.stubs(:llm_service).returns(@mock_llm_service)
    
    result = service.call
    
    assert result[:success]
    extracted_params = result[:data][:extracted_parameters]
    assert_equal 'awareness', extracted_params['campaign_type']
    assert_equal 'increase brand visibility', extracted_params['primary_objective']
  end

  test "should advance conversation state based on extracted parameters" do
    conversation_data = {
      state: 'initial',
      extracted_parameters: { 'campaign_type' => 'awareness', 'primary_objective' => 'brand visibility' },
      question_count: 1
    }
    
    # Mock LLM responses
    @mock_llm_service.stubs(:generate_analytics_insights).returns({
      insights: ['{"target_audience": "tech professionals"}']
    })
    @mock_llm_service.stubs(:generate_campaign_plan).returns({
      summary: "What's your budget range for this campaign?"
    })

    service = CampaignIntakeService.new(
      user: @user,
      conversation_data: conversation_data,
      user_response: "We want to target tech professionals"
    )
    service.stubs(:llm_service).returns(@mock_llm_service)
    
    result = service.call
    
    assert result[:success]
    # Should advance from initial to gathering_basics or beyond
    assert_not_equal 'initial', result[:data][:conversation_state]
  end

  test "should complete intake when sufficient parameters collected" do
    conversation_data = {
      state: 'finalizing_parameters',
      extracted_parameters: {
        'campaign_type' => 'awareness',
        'primary_objective' => 'increase brand visibility',
        'target_audience' => 'tech professionals',
        'budget_range' => '$10,000',
        'timeline' => '2 months'
      },
      question_count: 5
    }
    
    service = CampaignIntakeService.new(
      user: @user,
      conversation_data: conversation_data,
      user_response: "That sounds perfect!"
    )
    service.stubs(:llm_service).returns(@mock_llm_service)
    
    result = service.call
    
    assert result[:success]
    assert result[:data][:completed]
    assert_not_nil result[:data][:final_parameters]
    assert_not_nil result[:data][:summary]
  end

  test "should handle LLM service errors gracefully" do
    # Make LLM service raise an error
    @mock_llm_service.stubs(:generate_social_media_content).raises(StandardError, "LLM service unavailable")
    
    result = @service.call
    
    assert_not result[:success]
    assert_includes result[:error], "LLM service unavailable"
  end

  test "should calculate progress correctly" do
    conversation_data = {
      extracted_parameters: {
        'campaign_type' => 'awareness',
        'primary_objective' => 'brand visibility',
        'target_audience' => 'tech professionals'
      }
    }
    
    service = CampaignIntakeService.new(user: @user, conversation_data: conversation_data)
    progress = service.send(:calculate_progress)
    
    assert_equal 50, progress[:percentage] # 3 out of 6 required parameters
    assert_equal 3, progress[:parameters_collected]
    assert_equal 6, progress[:total_parameters]
    assert_includes progress[:missing_parameters], 'budget_range'
    assert_includes progress[:missing_parameters], 'timeline'
  end

  test "should fill missing parameters with defaults on completion" do
    partial_parameters = {
      'campaign_type' => 'awareness',
      'primary_objective' => 'brand visibility'
    }
    
    service = CampaignIntakeService.new(user: @user)
    filled = service.send(:fill_missing_parameters, partial_parameters)
    
    assert_equal 'awareness', filled['campaign_type']
    assert_equal 'brand visibility', filled['primary_objective']
    assert_equal 'potential customers', filled['target_audience'] # default
    assert_equal 'flexible', filled['budget_range'] # default
    assert_equal 'within 1-2 months', filled['timeline'] # default
  end

  test "should parse JSON from LLM response correctly" do
    service = CampaignIntakeService.new(user: @user)
    
    # Test clean JSON response
    response = { insights: ['{"campaign_type": "awareness", "budget": "$5000"}'] }
    parsed = service.send(:parse_parameter_extraction_response, response)
    
    assert_equal 'awareness', parsed['campaign_type']
    assert_equal '$5000', parsed['budget']
  end

  test "should handle malformed JSON gracefully" do
    service = CampaignIntakeService.new(user: @user)
    
    # Test malformed JSON
    response = { insights: ['This is not JSON at all'] }
    parsed = service.send(:parse_parameter_extraction_response, response)
    
    assert_equal({}, parsed)
  end

  test "should generate fallback questions when LLM fails" do
    service = CampaignIntakeService.new(user: @user, conversation_data: { state: 'initial' })
    
    question = service.send(:generate_fallback_question)
    
    assert_not_nil question
    assert question.length > 10
    assert question.include?('goal')
  end

  test "should respect conversation question limit" do
    conversation_data = {
      state: 'gathering_basics',
      extracted_parameters: { 'campaign_type' => 'awareness' },
      question_count: 10 # At limit
    }
    
    service = CampaignIntakeService.new(user: @user, conversation_data: conversation_data)
    service.stubs(:llm_service).returns(@mock_llm_service)
    
    result = service.call
    
    assert result[:success]
    assert result[:data][:completed] # Should complete due to question limit
  end

  test "should maintain conversation history correctly" do
    # Mock LLM responses
    @mock_llm_service.stubs(:generate_analytics_insights).returns({
      insights: ['{"campaign_type": "awareness"}']
    })
    @mock_llm_service.stubs(:generate_campaign_plan).returns({
      summary: "What's your target audience?"
    })

    service = CampaignIntakeService.new(
      user: @user,
      user_response: "I want to launch a new product"
    )
    service.stubs(:llm_service).returns(@mock_llm_service)
    
    result = service.call
    
    conversation_history = result[:data][:conversation_data][:conversation_history]
    
    assert_equal 2, conversation_history.length
    assert_equal 'user_response', conversation_history[0][:type]
    assert_equal 'ai_question', conversation_history[1][:type]
    assert_equal 'I want to launch a new product', conversation_history[0][:content]
  end

  test "should format conversation context for LLM prompts" do
    conversation_data = {
      conversation_history: [
        { type: 'ai_question', content: 'What is your goal?', timestamp: Time.current },
        { type: 'user_response', content: 'Increase sales', timestamp: Time.current }
      ]
    }
    
    service = CampaignIntakeService.new(user: @user, conversation_data: conversation_data)
    context = service.send(:format_conversation_context)
    
    assert_includes context, 'ai_question: What is your goal?'
    assert_includes context, 'user_response: Increase sales'
  end

  test "should determine correct conversation state transitions" do
    service = CampaignIntakeService.new(user: @user, conversation_data: { state: 'initial' })
    
    # Mock completion percentage
    service.stubs(:calculate_completion_percentage).returns(25)
    service.instance_variable_set(:@question_count, 2)
    
    service.send(:advance_conversation_state)
    current_state = service.instance_variable_get(:@current_state)
    
    assert_equal 'gathering_basics', current_state
  end

  test "should map campaign types correctly" do
    # This tests the private method through a job that would use it
    # Since we're testing the service, we'll test the intake completion flow
    conversation_data = {
      state: 'finalizing_parameters',
      extracted_parameters: {
        'campaign_type' => 'upsell',
        'primary_objective' => 'increase revenue from existing customers',
        'target_audience' => 'current customers',
        'budget_range' => '$5,000',
        'timeline' => '1 month',
        'key_messaging' => 'additional value'
      },
      question_count: 6
    }
    
    service = CampaignIntakeService.new(user: @user, conversation_data: conversation_data)
    service.stubs(:llm_service).returns(@mock_llm_service)
    
    result = service.call
    
    assert result[:success]
    assert result[:data][:completed]
    final_params = result[:data][:final_parameters]
    
    # Should map 'upsell' to valid Journey campaign type
    assert_equal 'upsell', final_params['campaign_type']
  end

  test "should generate intake summary on completion" do
    parameters = {
      'campaign_type' => 'awareness',
      'target_audience' => 'tech professionals',
      'primary_objective' => 'increase brand visibility',
      'timeline' => '2 months',
      'budget_range' => '$10,000'
    }
    
    service = CampaignIntakeService.new(user: @user)
    summary = service.send(:generate_intake_summary, parameters)
    
    assert_includes summary, 'awareness campaign'
    assert_includes summary, 'tech professionals'
    assert_includes summary, 'increase brand visibility'
    assert_includes summary, '2 months'
    assert_includes summary, '$10,000'
  end
end