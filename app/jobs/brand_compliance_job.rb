class BrandComplianceJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard jobs with permanent failures after retries
  discard_on ActiveJob::DeserializationError

  def perform(brand_id, content, content_type, options = {})
    brand = Brand.find(brand_id)
    
    # Initialize event broadcaster if real-time updates are enabled
    broadcaster = if options[:broadcast_events]
      Branding::Compliance::EventBroadcaster.new(
        brand_id,
        options[:session_id],
        options[:user_id]
      )
    end
    
    # Broadcast start event
    broadcaster&.broadcast_validation_start({
      type: content_type,
      length: content.length,
      validators: determine_validators(content_type, options)
    })
    
    # Perform compliance check
    service = Branding::ComplianceServiceV2.new(brand, content, content_type, options)
    results = service.check_compliance
    
    # Store results if requested
    if options[:store_results]
      store_compliance_results(brand, results, options)
    end
    
    # Broadcast completion
    broadcaster&.broadcast_validation_complete(results)
    
    # Send notifications if needed
    send_notifications(brand, results, options) if options[:notify]
    
    # Return results for job tracking
    results
  rescue StandardError => e
    handle_job_error(e, broadcaster, options)
    raise # Re-raise for retry mechanism
  end

  private

  def determine_validators(content_type, options)
    validators = ["Rule Engine"]
    validators << "NLP Analyzer" unless content_type.include?("visual")
    validators << "Visual Validator" if content_type.include?("visual") || content_type.include?("image")
    validators
  end

  def store_compliance_results(brand, results, options)
    ComplianceResult.create!(
      brand: brand,
      content_type: options[:content_type],
      content_hash: Digest::SHA256.hexdigest(options[:content_identifier] || ""),
      compliant: results[:compliant],
      score: results[:score],
      violations_count: results[:violations]&.count || 0,
      violations_data: results[:violations],
      suggestions_data: results[:suggestions],
      analysis_data: results[:analysis],
      metadata: {
        processing_time: results[:metadata][:processing_time],
        validators_used: results[:metadata][:validators_used],
        options: options.except(:content)
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to store compliance results: #{e.message}"
  end

  def send_notifications(brand, results, options)
    return if results[:compliant] && !options[:notify_on_success]
    
    # Determine notification recipients
    recipients = determine_recipients(brand, options)
    
    # Send appropriate notifications
    if results[:compliant]
      ComplianceMailer.compliance_passed(brand, results, recipients).deliver_later
    else
      ComplianceMailer.compliance_failed(brand, results, recipients).deliver_later
    end
    
    # Send in-app notifications if enabled
    if options[:in_app_notifications]
      create_in_app_notifications(brand, results, recipients)
    end
  end

  def determine_recipients(brand, options)
    recipients = []
    
    # Brand owner
    recipients << brand.user if options[:notify_owner]
    
    # Specified users
    if options[:notify_users]
      recipients.concat(User.where(id: options[:notify_users]))
    end
    
    # Team members with appropriate permissions
    if options[:notify_team]
      recipients.concat(brand.team_members.with_permission(:view_compliance))
    end
    
    recipients.uniq
  end

  def create_in_app_notifications(brand, results, recipients)
    recipients.each do |recipient|
      Notification.create!(
        user: recipient,
        notifiable: brand,
        action: results[:compliant] ? "compliance_passed" : "compliance_failed",
        data: {
          score: results[:score],
          violations_count: results[:violations]&.count || 0,
          summary: results[:summary]
        }
      )
    end
  end

  def handle_job_error(error, broadcaster, options)
    Rails.logger.error "Compliance job error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    # Broadcast error event
    broadcaster&.broadcast_error({
      type: error.class.name,
      message: error.message,
      recoverable: !error.is_a?(ActiveRecord::RecordNotFound)
    })
    
    # Store error information if requested
    if options[:store_errors]
      ComplianceError.create!(
        brand_id: options[:brand_id],
        error_type: error.class.name,
        error_message: error.message,
        error_backtrace: error.backtrace,
        job_params: options
      )
    end
  end
end