class AIGenerationJob < ApplicationJob
  queue_as :ai_generation
  
  # Job-specific error classes
  class ContentBlockedError < StandardError; end
  class ContentValidationError < StandardError; end
  
  # Configure retries with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  retry_on Net::TimeoutError, wait: 10.seconds, attempts: 3
  retry_on Faraday::TimeoutError, wait: 10.seconds, attempts: 3
  
  # Discard jobs that fail due to invalid requests or blocked content
  discard_on ArgumentError
  discard_on ActiveRecord::RecordNotFound
  discard_on ContentBlockedError
  discard_on ContentValidationError

  def perform(generation_request_id, content_type, prompt_data)
    Rails.logger.info "Starting AI generation for request #{generation_request_id}"
    
    # Update job status to processing
    update_job_status(generation_request_id, 'processing', { started_at: Time.current })
    
    begin
      generation_request = AIGenerationRequest.find(generation_request_id)
      
      # Generate content using AI service
      ai_service = AIService.new
      raw_result = ai_service.generate_content(content_type, prompt_data)
      
      # Parse the AI response
      parser = AiResponseParser.new(
        provider: determine_provider(ai_service),
        response_type: content_type,
        strict_validation: true
      )
      parsed_result = parser.parse(raw_result)
      
      # Validate content quality and appropriateness
      validator = AiContentValidator.new(
        validation_types: ['quality', 'appropriateness', 'content_structure', 'marketing_effectiveness'],
        content_category: content_type,
        brand_guidelines: extract_brand_guidelines(generation_request),
        min_quality_score: 70
      )
      validation_results = validator.validate(parsed_result[:content])
      
      # Apply content moderation
      moderator = AiContentModerator.new(
        enabled_categories: ['profanity', 'spam', 'personal_info', 'adult_content'],
        strictness_level: 'medium',
        redact_personal_info: true
      )
      moderation_results = moderator.moderate(parsed_result[:content])
      
      # Transform to consistent format
      transformer = AiResponseTransformer.new(
        target_format: determine_target_format(content_type),
        transformation_options: ['normalize_whitespace', 'extract_metadata', 'add_timestamps']
      )
      transformation_results = transformer.transform(parsed_result[:content])
      
      # Check if content should be blocked or flagged
      if moderation_results[:blocked]
        raise ContentBlockedError, "Content blocked by moderation: #{moderation_results[:overall_action]}"
      end
      
      if validation_results[:overall_status] == 'fail'
        raise ContentValidationError, "Content failed validation: #{validation_results[:summary]}"
      end
      
      # Prepare final result
      final_result = {
        content: transformation_results[:transformed_content],
        metadata: {
          original_metadata: raw_result[:metadata],
          parsing: parsed_result.except(:content),
          validation: validation_results,
          moderation: moderation_results,
          transformation: transformation_results[:metadata]
        },
        quality_score: validation_results[:overall_score],
        moderation_status: moderation_results[:overall_action],
        flagged_for_review: moderation_results[:flagged] || validation_results[:overall_status] == 'warning'
      }
      
      # Store the processed content
      generation_request.update!(
        status: final_result[:flagged_for_review] ? 'review' : 'completed',
        generated_content: final_result[:content],
        metadata: final_result[:metadata],
        completed_at: Time.current
      )
      
      # Update job status to completed
      update_job_status(generation_request_id, 'completed', { 
        completed_at: Time.current,
        content_length: final_result[:content].to_s.length,
        quality_score: final_result[:quality_score],
        moderation_status: final_result[:moderation_status],
        flagged_for_review: final_result[:flagged_for_review],
        tokens_used: raw_result[:metadata]&.dig(:tokens_used)
      })
      
      # Send webhook notification if configured
      send_completion_webhook(generation_request_id, 'completed', final_result)
      
      Rails.logger.info "AI generation completed for request #{generation_request_id} (Quality: #{final_result[:quality_score]}%, Status: #{final_result[:moderation_status]})"
      
    rescue => error
      Rails.logger.error "AI generation failed for request #{generation_request_id}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      
      # Update job status to failed
      update_job_status(generation_request_id, 'failed', { 
        error_message: error.message,
        error_class: error.class.name,
        failed_at: Time.current
      })
      
      # Send webhook notification for failure
      send_completion_webhook(generation_request_id, 'failed', { error: error.message })
      
      # Re-raise to trigger retry mechanism
      raise error
    end
  end

  private

  def update_job_status(generation_request_id, status, metadata = {})
    job_status = AIJobStatus.find_or_create_by(
      generation_request_id: generation_request_id,
      job_id: job_id
    )
    
    job_status.update!(
      status: status,
      progress_data: job_status.progress_data.merge(metadata),
      updated_at: Time.current
    )
  end

  def send_completion_webhook(generation_request_id, status, data)
    generation_request = AIGenerationRequest.find(generation_request_id)
    webhook_url = generation_request.webhook_url
    
    return unless webhook_url.present?
    
    WebhookNotificationJob.perform_later(
      webhook_url,
      {
        generation_request_id: generation_request_id,
        status: status,
        timestamp: Time.current.iso8601,
        data: data
      }
    )
  rescue => error
    Rails.logger.warn "Failed to send webhook notification: #{error.message}"
  end

  def determine_provider(ai_service)
    return 'unknown' unless ai_service.respond_to?(:ai_provider)
    
    provider = ai_service.ai_provider
    return 'unknown' unless provider.respond_to?(:provider_name)
    
    provider.provider_name.downcase
  end

  def determine_target_format(content_type)
    case content_type.to_s.downcase
    when 'social_media_post'
      'social_media'
    when 'ad_copy', 'advertisement'
      'ad_copy'
    when 'email_content', 'email'
      'email'
    when 'blog_post', 'article'
      'blog_post'
    when 'landing_page'
      'landing_page'
    when 'campaign_strategy'
      'campaign_plan'
    when 'brand_analysis'
      'brand_analysis'
    else
      'content_generation'
    end
  end

  def extract_brand_guidelines(generation_request)
    guidelines = {}
    
    # Extract from campaign if available
    if generation_request.campaign&.brand_identity
      brand_identity = generation_request.campaign.brand_identity
      
      guidelines.merge!(
        'brand_name' => brand_identity.name,
        'tone' => brand_identity.voice_tone,
        'required_terms' => extract_required_terms(brand_identity),
        'forbidden_terms' => extract_forbidden_terms(brand_identity),
        'voice_characteristics' => extract_voice_characteristics(brand_identity)
      ).compact
    end
    
    guidelines
  end

  def extract_required_terms(brand_identity)
    terms = []
    terms << brand_identity.name if brand_identity.name.present?
    
    # Extract terms from core values
    if brand_identity.core_values.present?
      # Simple extraction - split by common delimiters
      values_terms = brand_identity.core_values.split(/[,\n;]/).map(&:strip).reject(&:blank?)
      terms.concat(values_terms)
    end
    
    terms.uniq.compact
  end

  def extract_forbidden_terms(brand_identity)
    # This would typically come from a brand guidelines database
    # For now, return empty array
    []
  end

  def extract_voice_characteristics(brand_identity)
    characteristics = {}
    
    if brand_identity.voice_tone.present?
      tone = brand_identity.voice_tone.downcase
      
      # Map common tones to characteristics
      if tone.include?('professional') || tone.include?('formal')
        characteristics['formality'] = 'formal'
      elsif tone.include?('casual') || tone.include?('friendly')
        characteristics['formality'] = 'informal'
      end
      
      if tone.include?('enthusiastic') || tone.include?('excited')
        characteristics['enthusiasm'] = 'high'
      elsif tone.include?('calm') || tone.include?('reserved')
        characteristics['enthusiasm'] = 'low'
      end
    end
    
    characteristics
  end
end