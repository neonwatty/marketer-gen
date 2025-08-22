# frozen_string_literal: true

# Background job for processing campaign intake conversations asynchronously
# Handles LLM interactions and updates conversation state
class CampaignIntakeJob < ApplicationJob
  queue_as :default

  # Retry LLM failures with exponential backoff
  retry_on StandardError, wait: 5.seconds, attempts: 3

  # Don't retry if conversation data is invalid
  discard_on ArgumentError

  def perform(user_id:, conversation_data:, user_response: nil, callback_params: {})
    @user = User.find(user_id)
    @conversation_data = conversation_data
    @user_response = user_response
    @callback_params = callback_params

    Rails.logger.info "Processing campaign intake: user_id=#{user_id}, has_response=#{user_response.present?}, callback_present=#{callback_params.present?}"

    # Process the intake conversation
    result = CampaignIntakeService.call(
      user: @user,
      conversation_data: @conversation_data,
      user_response: @user_response
    )

    # Handle the result
    if result[:success]
      handle_successful_intake(result[:data])
    else
      handle_failed_intake(result[:error], result[:context])
    end

  rescue ActiveRecord::RecordNotFound
    # Re-raise RecordNotFound as-is for tests
    raise
  rescue => error
    Rails.logger.error "Campaign intake job failed: #{error.message} (user_id: #{user_id})"
    
    # Notify about the failure if callback is available and user is found
    notify_intake_failure(error) if @callback_params.present? && @user.present?
    
    raise error
  end

  private

  def handle_successful_intake(data)
    Rails.logger.info "Campaign intake processed successfully: user_id=#{@user.id}, completed=#{data[:completed]}, question_count=#{data.dig(:progress, :question_count)}"

    # Store conversation state if not completed
    if data[:completed]
      handle_completed_intake(data)
    else
      store_conversation_state(data)
    end

    # Notify about the result if callback is available
    notify_intake_result(data) if @callback_params.present?
  end

  def handle_completed_intake(data)
    # Create or update Journey with extracted parameters
    journey_params = build_journey_params(data[:final_parameters])
    
    if existing_journey_id = @conversation_data['journey_id']
      update_existing_journey(existing_journey_id, journey_params, data)
    else
      create_new_journey(journey_params, data)
    end

    # Clean up conversation data
    cleanup_conversation_data
  end

  def build_journey_params(parameters)
    {
      name: generate_journey_name(parameters),
      description: parameters['primary_objective'] || 'AI-generated campaign',
      campaign_type: map_campaign_type(parameters['campaign_type']),
      template_type: determine_template_type(parameters),
      status: 'draft',
      metadata: {
        intake_source: 'llm_guided',
        extracted_parameters: parameters,
        intake_completed_at: Time.current,
        budget_range: parameters['budget_range'],
        timeline: parameters['timeline'],
        target_audience: parameters['target_audience'],
        key_messaging: parameters['key_messaging']
      }
    }
  end

  def generate_journey_name(parameters)
    objective = parameters['primary_objective'] || 'campaign'
    campaign_type = parameters['campaign_type'] || 'marketing'
    
    "#{campaign_type.humanize} Campaign: #{objective.humanize}"
  end

  def map_campaign_type(llm_campaign_type)
    # Map LLM extracted campaign types to Journey model campaign types
    mapping = {
      'awareness' => 'awareness',
      'consideration' => 'consideration', 
      'conversion' => 'conversion',
      'retention' => 'retention',
      'upsell_cross_sell' => 'upsell_cross_sell',
      'upsell' => 'upsell_cross_sell',
      'cross_sell' => 'upsell_cross_sell'
    }
    
    mapped = mapping[llm_campaign_type.to_s.downcase]
    mapped || 'awareness' # Default fallback
  end

  def determine_template_type(parameters)
    # Determine template type based on extracted parameters
    messaging = parameters['key_messaging'].to_s.downcase
    objective = parameters['primary_objective'].to_s.downcase
    
    if messaging.include?('email') || objective.include?('email')
      'email'
    elsif messaging.include?('social') || objective.include?('social')
      'social_media'
    elsif messaging.include?('webinar') || messaging.include?('event') || objective.include?('webinar') || objective.include?('event')
      'event'
    elsif messaging.include?('content') || objective.include?('content')
      'content'
    else
      'custom'
    end
  end

  def create_new_journey(journey_params, intake_data)
    journey = @user.journeys.create!(journey_params)
    
    Rails.logger.info "Created journey from intake: journey_id=#{journey.id}, user_id=#{@user.id}, campaign_type=#{journey.campaign_type}"

    # Store journey reference for callback
    @created_journey = journey
    
    # Optionally trigger journey template selection
    schedule_template_suggestion(journey, intake_data[:final_parameters])
  end

  def update_existing_journey(journey_id, journey_params, intake_data)
    journey = @user.journeys.find(journey_id)
    journey.update!(journey_params)
    
    Rails.logger.info "Updated journey from intake: journey_id=#{journey.id}, user_id=#{@user.id}"

    @updated_journey = journey
  end

  def schedule_template_suggestion(journey, parameters)
    # Schedule a job to suggest appropriate journey templates
    JourneySuggestionJob.perform_later(
      journey_id: journey.id,
      parameters: parameters
    )
  rescue NameError
    # JourneySuggestionJob doesn't exist yet, skip
    Rails.logger.debug "JourneySuggestionJob not available, skipping template suggestion"
  end

  def store_conversation_state(data)
    # Store conversation state in cache or session for continuation
    cache_key = "campaign_intake:#{@user.id}:conversation"
    
    Rails.cache.write(
      cache_key,
      data[:conversation_data],
      expires_in: 1.hour
    )

    Rails.logger.debug "Stored conversation state: user_id=#{@user.id}, state=#{data[:conversation_state]}, progress=#{data[:progress][:percentage]}"
  end

  def cleanup_conversation_data
    # Remove cached conversation data after completion
    cache_key = "campaign_intake:#{@user.id}:conversation"
    Rails.cache.delete(cache_key)
    
    Rails.logger.debug "Cleaned up conversation data: user_id=#{@user.id}"
  end

  def handle_failed_intake(error_message, context)
    Rails.logger.error "Campaign intake service failed", {
      error: error_message,
      context: context,
      user_id: @user.id
    }

    # Store error state for potential recovery
    error_cache_key = "campaign_intake:#{@user.id}:error"
    Rails.cache.write(
      error_cache_key,
      {
        error: error_message,
        context: context,
        occurred_at: Time.current,
        conversation_data: @conversation_data
      },
      expires_in: 1.hour
    )
  end

  def notify_intake_result(data)
    # Notify external systems about intake completion/progress
    notification_data = {
      user_id: @user.id,
      completed: data[:completed],
      progress: data[:progress]
    }

    # Add additional data for webhooks but keep ActionCable minimal
    notification_type = @callback_params[:notification_type] || @callback_params['notification_type']
    if notification_type == 'webhook'
      notification_data[:timestamp] = Time.current
      if data[:completed]
        notification_data[:journey_id] = @created_journey&.id || @updated_journey&.id
        notification_data[:final_parameters] = data[:final_parameters]
      else
        notification_data[:next_question] = data[:question]
        notification_data[:conversation_state] = data[:conversation_state]
      end
    end

    # Send notification via webhook, ActionCable, etc.
    send_intake_notification(notification_data)
  end

  def notify_intake_failure(error)
    notification_data = {
      user_id: @user.id,
      error: error.message,
      error_type: error.class.name,
      timestamp: Time.current,
      conversation_data: @conversation_data
    }

    send_intake_notification(notification_data, type: 'error')
  end

  def send_intake_notification(data, type: 'update')
    # Implementation depends on notification system
    notification_type = @callback_params[:notification_type] || @callback_params['notification_type']
    case notification_type
    when 'webhook'
      send_webhook_notification(data, type)
    when 'actioncable'
      send_actioncable_notification(data, type)
    when 'email'
      send_email_notification(data, type) if type == 'error'
    else
      Rails.logger.debug "No notification type specified: #{data}"
    end
  end

  def send_webhook_notification(data, type)
    webhook_url = @callback_params[:webhook_url] || @callback_params['webhook_url']
    return unless webhook_url.present?

    # Send HTTP POST to webhook URL
    # Implementation would use HTTP client like Faraday or Net::HTTP
    Rails.logger.info "Would send webhook notification", {
      url: webhook_url,
      type: type,
      data_keys: data.keys
    }
  end

  def send_actioncable_notification(data, type)
    channel_name = @callback_params[:channel_name] || @callback_params['channel_name']
    return unless channel_name.present?

    # Broadcast via ActionCable
    ActionCable.server.broadcast(
      channel_name,
      {
        type: "campaign_intake_#{type}",
        data: data
      }
    )
  rescue => error
    Rails.logger.error "ActionCable notification failed: #{error.message}"
  end

  def send_email_notification(data, type)
    admin_email = @callback_params[:admin_email] || @callback_params['admin_email']
    return unless type == 'error' && admin_email.present?

    # Send error notification email to admin
    # Implementation would use ActionMailer
    Rails.logger.info "Would send error email: email=#{admin_email}, error=#{data[:error]}"
  end
end