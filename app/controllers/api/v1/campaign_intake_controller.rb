class Api::V1::CampaignIntakeController < Api::V1::BaseController
  before_action :set_session, only: [:message, :save_thread, :get_thread]
  
  # POST /api/v1/campaign-intake/message
  def message
    thread_id = params[:threadId] || SecureRandom.uuid
    content = params[:content]
    question_id = params[:questionId]
    context = params[:context] || {}
    
    return render_error(message: 'Content is required') if content.blank?
    
    begin
      # Load or create conversation thread
      thread = load_or_create_thread(thread_id, context)
      
      # Process the message with LLM service
      response_data = CampaignIntakeLlmService.new(
        thread: thread,
        user_message: content,
        question_id: question_id,
        context: context,
        user: current_user
      ).process_message
      
      # Save thread to session/database
      save_thread_data(thread_id, response_data[:thread])
      
      render_success(data: response_data)
      
    rescue => e
      Rails.logger.error "Campaign intake error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render_error(
        message: 'Failed to process message',
        errors: { system: e.message }
      )
    end
  end
  
  # POST /api/v1/campaign-intake/threads
  def save_thread
    thread_data = params[:thread]
    return render_error(message: 'Thread data is required') if thread_data.blank?
    
    begin
      # Save to session for persistence
      session[:campaign_intake_threads] ||= {}
      session[:campaign_intake_threads][thread_data[:id]] = thread_data.to_h
      
      # Optionally save to database for long-term persistence
      intake_session = CampaignIntakeSession.find_or_create_by(
        user: current_user,
        thread_id: thread_data[:id]
      )
      
      intake_session.update!(
        context: thread_data[:context],
        status: thread_data[:status] || 'in_progress',
        updated_at: Time.current
      )
      
      render_success(message: 'Thread saved successfully')
      
    rescue => e
      Rails.logger.error "Failed to save thread: #{e.message}"
      render_error(message: 'Failed to save conversation')
    end
  end
  
  # GET /api/v1/campaign-intake/threads/:id
  def get_thread
    thread_id = params[:id]
    
    begin
      # Try session first
      thread_data = session[:campaign_intake_threads]&.[](thread_id)
      
      # Fall back to database
      unless thread_data
        intake_session = current_user.campaign_intake_sessions.find_by(thread_id: thread_id)
        if intake_session
          thread_data = {
            id: thread_id,
            messages: intake_session.messages || [],
            context: intake_session.context || {},
            status: intake_session.status,
            createdAt: intake_session.created_at,
            updatedAt: intake_session.updated_at
          }
        end
      end
      
      if thread_data
        render_success(data: thread_data)
      else
        render_error(message: 'Thread not found', status: :not_found)
      end
      
    rescue => e
      Rails.logger.error "Failed to load thread: #{e.message}"
      render_error(message: 'Failed to load conversation')
    end
  end
  
  # GET /api/v1/campaign-intake/questionnaire
  def questionnaire
    begin
      questionnaire = CampaignIntakeQuestionnaireService.new(
        user: current_user,
        context: params[:context] || {}
      ).generate_questionnaire
      
      render_success(data: questionnaire)
      
    rescue => e
      Rails.logger.error "Failed to generate questionnaire: #{e.message}"
      render_error(message: 'Failed to load questionnaire')
    end
  end
  
  # POST /api/v1/campaign-intake/complete
  def complete
    thread_id = params[:threadId]
    context = params[:context] || {}
    
    return render_error(message: 'Thread ID is required') if thread_id.blank?
    
    begin
      # Create campaign from conversation context
      campaign_data = CampaignCreationService.new(
        user: current_user,
        context: context,
        thread_id: thread_id
      ).create_campaign
      
      # Mark intake session as completed
      intake_session = current_user.campaign_intake_sessions.find_by(thread_id: thread_id)
      if intake_session
        intake_session.update!(
          status: 'completed',
          completed_at: Time.current,
          actual_completion_time: calculate_completion_time(intake_session)
        )
      end
      
      render_success(
        data: campaign_data,
        message: 'Campaign created successfully'
      )
      
    rescue => e
      Rails.logger.error "Failed to complete campaign intake: #{e.message}"
      render_error(message: 'Failed to create campaign')
    end
  end
  
  private
  
  def set_session
    # Ensure session is available for storing conversation data
    session[:campaign_intake_threads] ||= {}
  end
  
  def load_or_create_thread(thread_id, context)
    # Try to load existing thread from session
    existing_thread = session[:campaign_intake_threads][thread_id]
    
    if existing_thread
      {
        id: thread_id,
        messages: existing_thread['messages'] || [],
        context: existing_thread['context'] || context,
        status: existing_thread['status'] || 'active',
        created_at: Time.parse(existing_thread['createdAt']) rescue Time.current,
        updated_at: Time.current
      }
    else
      # Create new thread
      {
        id: thread_id,
        messages: [],
        context: default_context.merge(context),
        status: 'active',
        created_at: Time.current,
        updated_at: Time.current
      }
    end
  end
  
  def save_thread_data(thread_id, thread_data)
    session[:campaign_intake_threads][thread_id] = thread_data.with_indifferent_access
  end
  
  def default_context
    {
      completedSteps: [],
      currentStep: 'welcome',
      progress: 0
    }
  end
  
  def calculate_completion_time(intake_session)
    return 0 unless intake_session.started_at
    
    ((Time.current - intake_session.started_at) / 1.minute).round(1)
  end
end