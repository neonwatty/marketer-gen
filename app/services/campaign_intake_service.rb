# frozen_string_literal: true

# Service for conducting LLM-guided campaign intake conversations
# Dynamically generates questions based on user responses and extracts campaign parameters
class CampaignIntakeService < ApplicationService
  include LlmServiceHelper

  # States of the intake conversation
  CONVERSATION_STATES = %w[
    initial
    gathering_basics
    refining_objectives
    collecting_constraints
    finalizing_parameters
    completed
  ].freeze

  # Required campaign parameters we need to extract
  REQUIRED_PARAMETERS = %w[
    campaign_type
    primary_objective
    target_audience
    budget_range
    timeline
    key_messaging
  ].freeze

  def initialize(user:, conversation_data: {}, user_response: nil)
    @user = user
    @conversation_data = conversation_data.with_indifferent_access
    @user_response = user_response
    @current_state = @conversation_data[:state] || 'initial'
    @extracted_parameters = @conversation_data[:extracted_parameters] || {}
    @conversation_history = @conversation_data[:conversation_history] || []
    @question_count = @conversation_data[:question_count] || 0
  end

  def call
    Rails.logger.info "Service Call: CampaignIntakeService with params: #{
      {
        state: @current_state,
        question_count: @question_count,
        has_user_response: @user_response.present?
      }.inspect
    }"

    # Process user response if provided
    process_user_response if @user_response.present?

    # Generate next question or complete intake
    if intake_complete?
      finalize_intake
    else
      generate_next_question
    end
  rescue => error
    Rails.logger.error "Service Error in #{self.class}: #{error.message}"
    Rails.logger.error "Context: current_state=#{@current_state}, question_count=#{@question_count}, user_id=#{@user.id}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Return a structured error response
    {
      success: false,
      error: error.message,
      context: {
        current_state: @current_state,
        question_count: @question_count,
        user_id: @user.id
      }
    }
  end

  private

  def process_user_response
    # Add user response to conversation history
    @conversation_history << {
      type: 'user_response',
      content: @user_response,
      timestamp: Time.current,
      state: @current_state
    }

    # Extract parameters from user response using LLM
    extracted_params = extract_parameters_from_response(@user_response)
    
    # Merge extracted parameters
    @extracted_parameters.merge!(extracted_params) if extracted_params.present?

    # Advance conversation state based on extracted parameters
    advance_conversation_state
  end

  def extract_parameters_from_response(response)
    prompt = build_parameter_extraction_prompt(response)
    
    llm_response = llm_service.generate_analytics_insights({
      prompt: prompt,
      context: current_conversation_context,
      format: 'structured_json'
    })

    parse_parameter_extraction_response(llm_response)
  rescue => error
    Rails.logger.error "Parameter extraction failed: #{error.message}"
    {} # Return empty hash on error, conversation can continue
  end

  def build_parameter_extraction_prompt(user_response)
    <<~PROMPT
      You are an expert marketing campaign consultant analyzing a user's response to extract campaign parameters.

      Current conversation context:
      #{format_conversation_context}

      User's latest response: "#{user_response}"

      Please extract any campaign parameters from this response and return them as JSON.
      
      Look for these parameters:
      - campaign_type: (awareness, consideration, conversion, retention, upsell_cross_sell)
      - primary_objective: (specific goal they want to achieve)
      - target_audience: (who they want to reach)
      - budget_range: (any budget information mentioned)
      - timeline: (when they want to launch or duration)
      - key_messaging: (core messages or themes)
      - industry: (what industry they're in)
      - company_size: (size of their company)
      - previous_experience: (past campaign experience)

      Return ONLY a JSON object with extracted parameters. If no parameters can be extracted, return an empty object {}.
      
      Example response:
      {
        "campaign_type": "awareness",
        "primary_objective": "increase brand visibility in the tech sector",
        "target_audience": "B2B technology decision makers",
        "timeline": "launch within 2 months"
      }
    PROMPT
  end

  def parse_parameter_extraction_response(llm_response)
    # Extract JSON from LLM response
    response_content = llm_response.is_a?(Hash) ? llm_response[:insights]&.first : llm_response.to_s
    return {} unless response_content.present?

    # Look for JSON in the response
    json_match = response_content.match(/\{.*\}/m)
    return {} unless json_match

    JSON.parse(json_match[0])
  rescue JSON::ParserError => error
    Rails.logger.error "Failed to parse parameter extraction JSON: #{error.message}"
    {}
  end

  def generate_next_question
    prompt = build_question_generation_prompt
    
    # For now, use generate_social_media_content as it returns text content
    # In a real implementation, we'd have a dedicated conversation method
    llm_response = llm_service.generate_social_media_content({
      prompt: prompt,
      context: current_conversation_context,
      format: 'conversational_question',
      platform: 'general',
      tone: 'professional'
    })

    question = parse_question_response(llm_response)
    
    # Add question to conversation history
    @conversation_history << {
      type: 'ai_question',
      content: question,
      timestamp: Time.current,
      state: @current_state
    }

    @question_count += 1

    {
      success: true,
      data: {
        question: question,
        conversation_state: @current_state,
        conversation_data: build_conversation_data,
        progress: calculate_progress,
        extracted_parameters: @extracted_parameters.dup
      }
    }
  end

  def build_question_generation_prompt
    missing_params = missing_parameters
    
    <<~PROMPT
      You are an expert marketing consultant conducting a campaign intake interview.

      Current conversation state: #{@current_state}
      Question count: #{@question_count}

      Already extracted parameters:
      #{format_extracted_parameters}

      Still needed parameters:
      #{missing_params.join(', ')}

      Conversation history:
      #{format_conversation_history}

      Generate the next question to ask the user. The question should:
      1. Be conversational and friendly, not interrogative
      2. Focus on gathering one of the missing parameters
      3. Build naturally on the conversation so far
      4. Be specific enough to get actionable information
      5. Provide context about why you're asking if helpful

      Guidelines for each state:
      - initial: Welcome and ask about their main marketing goal
      - gathering_basics: Ask about company, industry, target audience
      - refining_objectives: Dig deeper into specific objectives and success metrics
      - collecting_constraints: Ask about budget, timeline, resources
      - finalizing_parameters: Clarify any remaining details

      Return only the question text, no additional formatting or explanations.
    PROMPT
  end

  def parse_question_response(llm_response)
    # Extract question from LLM response (social media content format)
    response_content = if llm_response.is_a?(Hash)
                        llm_response[:content] || llm_response[:summary] || llm_response.values.first
                      else
                        llm_response.to_s
                      end

    # Clean up the response to get just the question
    question = response_content.to_s.strip
    question = question.gsub(/^(Question|Q):\s*/i, '') # Remove "Question:" prefix
    question = question.split("\n").first # Take first line if multiline
    
    # If the response doesn't look like a question, generate fallback
    if question.present? && (question.include?('?') || question.length > 20)
      question
    else
      generate_fallback_question
    end
  end

  def generate_fallback_question
    missing_params = missing_parameters
    
    case @current_state
    when 'initial'
      "Hi! I'm here to help you create an effective marketing campaign. What's the main goal you're hoping to achieve with your next campaign?"
    when 'gathering_basics'
      if missing_params.include?('target_audience')
        "Who is your ideal target audience for this campaign?"
      else
        "What industry or market are you in?"
      end
    when 'refining_objectives'
      "What would success look like for this campaign? How will you measure if it's working?"
    when 'collecting_constraints'
      if missing_params.include?('budget_range')
        "What budget range are you working with for this campaign?"
      else
        "When are you hoping to launch this campaign?"
      end
    else
      "Is there anything else about your campaign goals or requirements you'd like to share?"
    end
  end

  def advance_conversation_state
    current_index = CONVERSATION_STATES.index(@current_state)
    completion_percentage = calculate_completion_percentage

    # Advance state based on completion and question count
    if completion_percentage >= 80 && @current_state != 'completed'
      @current_state = 'finalizing_parameters'
    elsif completion_percentage >= 60 && current_index < 3
      @current_state = CONVERSATION_STATES[3] # collecting_constraints
    elsif completion_percentage >= 40 && current_index < 2
      @current_state = CONVERSATION_STATES[2] # refining_objectives
    elsif completion_percentage >= 20 && current_index < 1
      @current_state = CONVERSATION_STATES[1] # gathering_basics
    elsif @question_count >= 8 # Prevent infinite conversations
      @current_state = 'finalizing_parameters'
    end
  end

  def intake_complete?
    # Complete if we have most required parameters or hit question limit
    completion_percentage = calculate_completion_percentage
    completion_percentage >= 75 || @question_count >= 10
  end

  def finalize_intake
    @current_state = 'completed'
    
    # Fill in any missing parameters with sensible defaults
    filled_parameters = fill_missing_parameters(@extracted_parameters)
    
    {
      success: true,
      data: {
        completed: true,
        final_parameters: filled_parameters,
        conversation_data: build_conversation_data,
        summary: generate_intake_summary(filled_parameters)
      }
    }
  end

  def fill_missing_parameters(params)
    defaults = {
      'campaign_type' => 'awareness',
      'primary_objective' => 'increase brand visibility and engagement',
      'target_audience' => 'potential customers',
      'budget_range' => 'flexible',
      'timeline' => 'within 1-2 months',
      'key_messaging' => 'value proposition and brand benefits'
    }

    defaults.merge(params)
  end

  def generate_intake_summary(parameters)
    "Campaign intake completed! We've identified a #{parameters['campaign_type']} campaign targeting #{parameters['target_audience']} with the objective to #{parameters['primary_objective']}. Timeline: #{parameters['timeline']}, Budget: #{parameters['budget_range']}."
  end

  def missing_parameters
    REQUIRED_PARAMETERS - @extracted_parameters.keys
  end

  def calculate_completion_percentage
    return 0 if REQUIRED_PARAMETERS.empty?
    ((@extracted_parameters.keys & REQUIRED_PARAMETERS).length.to_f / REQUIRED_PARAMETERS.length * 100).round
  end

  def calculate_progress
    {
      percentage: calculate_completion_percentage,
      parameters_collected: @extracted_parameters.keys.length,
      total_parameters: REQUIRED_PARAMETERS.length,
      missing_parameters: missing_parameters,
      question_count: @question_count
    }
  end

  def current_conversation_context
    {
      state: @current_state,
      extracted_parameters: @extracted_parameters,
      conversation_history: @conversation_history.last(3), # Recent context
      user_id: @user.id
    }
  end

  def build_conversation_data
    {
      state: @current_state,
      extracted_parameters: @extracted_parameters,
      conversation_history: @conversation_history,
      question_count: @question_count,
      updated_at: Time.current
    }
  end

  def format_conversation_context
    if @conversation_history.empty?
      "This is the start of the conversation."
    else
      @conversation_history.last(3).map do |entry|
        "#{entry[:type]}: #{entry[:content]}"
      end.join("\n")
    end
  end

  def format_extracted_parameters
    if @extracted_parameters.empty?
      "None yet."
    else
      @extracted_parameters.map { |k, v| "#{k}: #{v}" }.join("\n")
    end
  end

  def format_conversation_history
    if @conversation_history.empty?
      "No conversation history yet."
    else
      @conversation_history.map do |entry|
        timestamp = entry[:timestamp]&.strftime("%H:%M") || "unknown"
        "#{timestamp} - #{entry[:type]}: #{entry[:content]}"
      end.join("\n")
    end
  end
end