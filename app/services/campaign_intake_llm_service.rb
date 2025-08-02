class CampaignIntakeLlmService
  include LlmServiceHelpers
  
  def initialize(thread:, user_message:, question_id: nil, context: {}, user:)
    @thread = thread
    @user_message = user_message
    @question_id = question_id
    @context = context
    @user = user
    @llm_service = LlmService.new
  end
  
  def process_message
    # Update thread with user message
    add_user_message
    
    # Determine next action based on context
    if @question_id.present?
      process_question_response
    else
      process_conversational_message
    end
    
    # Update thread context and determine next steps
    updated_thread = update_thread_context
    
    {
      message: @assistant_message,
      thread: updated_thread,
      nextQuestion: @next_question,
      suggestions: @suggestions,
      isComplete: @is_complete
    }
  end
  
  private
  
  def add_user_message
    @thread[:messages] << {
      id: SecureRandom.uuid,
      content: @user_message,
      type: 'user',
      timestamp: Time.current.iso8601,
      questionId: @question_id,
      metadata: {
        isQuestionResponse: @question_id.present?
      }
    }
  end
  
  def process_question_response
    # Find the question being answered
    question = find_question_by_id(@question_id)
    return process_conversational_message unless question
    
    # Validate the response
    validation_result = validate_response(@user_message, question)
    
    if validation_result[:valid]
      # Process valid response
      update_context_with_response(question, @user_message)
      generate_follow_up_response(question)
    else
      # Handle invalid response
      generate_validation_error_response(validation_result[:errors])
    end
  end
  
  def process_conversational_message
    # Use LLM to understand intent and generate appropriate response
    prompt = build_conversational_prompt
    
    begin
      llm_response = @llm_service.generate_campaign_intake_response(
        prompt: prompt,
        context: @thread[:context],
        user: @user
      )
      
      parse_llm_response(llm_response)
      
    rescue => e
      Rails.logger.error "LLM service error: #{e.message}"
      generate_fallback_response
    end
  end
  
  def build_conversational_prompt
    conversation_history = @thread[:messages].map do |msg|
      "#{msg[:type].capitalize}: #{msg[:content]}"
    end.join("\n")
    
    <<~PROMPT
      You are a helpful marketing campaign assistant. You're having a conversation with a user to help them create a marketing campaign.
      
      Current context:
      - Campaign Type: #{@thread[:context]['campaignType'] || 'Not specified'}
      - Target Audience: #{@thread[:context]['targetAudience'] || 'Not specified'}
      - Goals: #{@thread[:context]['goals']&.join(', ') || 'Not specified'}
      - Industry: #{@thread[:context]['industry'] || 'Not specified'}
      - Current Step: #{@thread[:context]['currentStep']}
      - Progress: #{@thread[:context]['progress']}%
      
      Conversation so far:
      #{conversation_history}
      
      Guidelines:
      1. Be conversational and helpful
      2. Ask clarifying questions to gather missing information
      3. Provide suggestions and examples
      4. Keep responses concise but informative
      5. Guide the user through the campaign creation process
      6. If you have enough information, suggest moving to the next step
      
      Respond in JSON format:
      {
        "content": "Your response message",
        "nextStep": "suggested_next_step",
        "suggestions": ["suggestion1", "suggestion2"],
        "contextUpdates": {"key": "value"},
        "isComplete": false
      }
    PROMPT
  end
  
  def parse_llm_response(llm_response)
    begin
      parsed = JSON.parse(llm_response)
      
      @assistant_message = {
        id: SecureRandom.uuid,
        content: parsed['content'],
        type: 'assistant',
        timestamp: Time.current.iso8601,
        metadata: {
          suggestions: parsed['suggestions'] || []
        }
      }
      
      @suggestions = parsed['suggestions'] || []
      @context_updates = parsed['contextUpdates'] || {}
      @next_step = parsed['nextStep']
      @is_complete = parsed['isComplete'] || false
      
    rescue JSON::ParserError
      # Fallback if LLM doesn't return valid JSON
      @assistant_message = {
        id: SecureRandom.uuid,
        content: llm_response,
        type: 'assistant',
        timestamp: Time.current.iso8601,
        metadata: {}
      }
      
      @suggestions = []
      @context_updates = {}
    end
  end
  
  def generate_follow_up_response(question)
    # Determine the next logical question or step
    next_question_data = determine_next_question
    
    if next_question_data
      @next_question = next_question_data
      @assistant_message = {
        id: SecureRandom.uuid,
        content: generate_question_introduction(next_question_data),
        type: 'assistant',
        timestamp: Time.current.iso8601,
        metadata: {
          suggestions: next_question_data[:suggestions] || []
        }
      }
    else
      # No more questions, provide summary or completion
      @assistant_message = {
        id: SecureRandom.uuid,
        content: generate_completion_message,
        type: 'assistant',
        timestamp: Time.current.iso8601,
        metadata: {}
      }
      @is_complete = true
    end
  end
  
  def generate_validation_error_response(errors)
    error_message = "I need a bit more information. #{errors.join(' ')}"
    
    @assistant_message = {
      id: SecureRandom.uuid,
      content: error_message,
      type: 'assistant',
      timestamp: Time.current.iso8601,
      metadata: {
        validationState: 'invalid'
      }
    }
  end
  
  def generate_fallback_response
    @assistant_message = {
      id: SecureRandom.uuid,
      content: "I understand. Let me help you with the next step in creating your campaign. What would you like to focus on next?",
      type: 'assistant',
      timestamp: Time.current.iso8601,
      metadata: {
        suggestions: [
          "Tell me about your target audience",
          "What are your campaign goals?",
          "What's your budget range?",
          "When do you want to launch?"
        ]
      }
    }
  end
  
  def update_thread_context
    # Merge context updates
    @thread[:context].merge!(@context_updates) if @context_updates
    @thread[:context].merge!(@context) if @context
    
    # Add assistant message to thread
    @thread[:messages] << @assistant_message
    
    # Update progress and current step
    update_progress_tracking
    
    @thread[:updated_at] = Time.current.iso8601
    @thread
  end
  
  def update_progress_tracking
    # Calculate progress based on completed information
    required_fields = %w[campaignType targetAudience goals industry]
    completed_fields = required_fields.count { |field| @thread[:context][field].present? }
    
    @thread[:context]['progress'] = ((completed_fields.to_f / required_fields.length) * 100).round
    
    # Update current step based on what's been completed
    @thread[:context]['currentStep'] = determine_current_step
    
    # Track completed steps
    @thread[:context]['completedSteps'] ||= []
    if @next_step && !@thread[:context]['completedSteps'].include?(@next_step)
      @thread[:context]['completedSteps'] << @next_step
    end
  end
  
  def determine_current_step
    context = @thread[:context]
    
    return 'campaign_type' unless context['campaignType'].present?
    return 'target_audience' unless context['targetAudience'].present?
    return 'goals' unless context['goals'].present?
    return 'industry' unless context['industry'].present?
    return 'budget' unless context['budget'].present?
    return 'timeline' unless context['timeline'].present?
    return 'channels' unless context['channels'].present?
    return 'review'
  end
  
  def find_question_by_id(question_id)
    # This would typically load from a configuration or database
    # For now, return a basic question structure
    questions_by_id[question_id]
  end
  
  def questions_by_id
    {
      'campaign_type' => {
        id: 'campaign_type',
        text: 'What type of campaign are you looking to create?',
        type: 'select',
        options: Campaign::CAMPAIGN_TYPES,
        contextKey: 'campaignType',
        required: true
      },
      'target_audience' => {
        id: 'target_audience',
        text: 'Who is your target audience for this campaign?',
        type: 'textarea',
        contextKey: 'targetAudience',
        required: true
      },
      'goals' => {
        id: 'goals',
        text: 'What are your primary goals for this campaign?',
        type: 'multiselect',
        options: ['Increase brand awareness', 'Generate leads', 'Drive sales', 'Improve engagement', 'Build community'],
        contextKey: 'goals',
        required: true
      }
    }
  end
  
  def determine_next_question
    context = @thread[:context]
    
    return questions_by_id['campaign_type'] unless context['campaignType'].present?
    return questions_by_id['target_audience'] unless context['targetAudience'].present?
    return questions_by_id['goals'] unless context['goals'].present?
    
    nil # No more questions
  end
  
  def generate_question_introduction(question)
    "Great! Now let's move on to the next step. #{question[:text]}"
  end
  
  def generate_completion_message
    context = @thread[:context]
    
    <<~MESSAGE
      Perfect! I have all the information I need to help you create your #{context['campaignType']} campaign.
      
      Here's a summary of what we've discussed:
      - Campaign Type: #{context['campaignType']}
      - Target Audience: #{context['targetAudience']}
      - Goals: #{context['goals']&.join(', ')}
      - Industry: #{context['industry']}
      
      I'm ready to create your campaign now. Would you like me to proceed?
    MESSAGE
  end
  
  def validate_response(response, question)
    errors = []
    
    # Basic validation
    if question[:required] && response.blank?
      errors << "This field is required."
      return { valid: false, errors: errors }
    end
    
    # Type-specific validation
    case question[:type]
    when 'select'
      unless question[:options]&.include?(response)
        errors << "Please select one of the provided options."
      end
    when 'number'
      unless response.match?(/^\d+(\.\d+)?$/)
        errors << "Please enter a valid number."
      end
    when 'email'
      unless response.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
        errors << "Please enter a valid email address."
      end
    end
    
    { valid: errors.empty?, errors: errors }
  end
  
  def update_context_with_response(question, response)
    context_key = question[:contextKey]
    @context_updates ||= {}
    
    case question[:type]
    when 'multiselect'
      @context_updates[context_key] = response.split(',').map(&:strip)
    when 'number'
      @context_updates[context_key] = response.to_f
    else
      @context_updates[context_key] = response
    end
  end
end