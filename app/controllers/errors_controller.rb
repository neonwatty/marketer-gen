class ErrorsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :verify_browser_compatibility
  
  def not_found
    render plain: "404 Not Found", status: 404
  end
  
  def unprocessable_entity
    @error_type = :unprocessable_entity
    @error_code = 422
    @error_message = "Unprocessable Request"
    @error_description = "We couldn't process your request due to invalid data or parameters."
    
    log_error_details
    render template: 'errors/422', status: :unprocessable_entity
  end
  
  def internal_server_error
    @error_type = :internal_server_error
    @error_code = 500
    @error_message = "Internal Server Error"
    @error_description = "Something went wrong on our end. We've been notified and are working to fix it."
    
    log_error_details
    render template: 'errors/500', status: :internal_server_error
  end
  
  def report_error
    return unless authenticated?
    
    report_params = params.require(:error_report).permit(:description, :error_type, :current_url, :expected_behavior)
    
    error_report_context = {
      user_id: current_user.id,
      user_email: current_user.email_address,
      description: report_params[:description],
      error_type: report_params[:error_type],
      current_url: report_params[:current_url],
      expected_behavior: report_params[:expected_behavior],
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      timestamp: Time.current
    }
    
    # Log the user report
    ActivityLogger.log(:info, "User error report submitted", error_report_context)
    
    # Send to admin
    if defined?(AdminMailer)
      AdminMailer.user_error_report(error_report_context).deliver_later
    end
    
    respond_to do |format|
      format.json { render json: { status: 'success', message: 'Thank you for your report. We will investigate this issue.' } }
      format.html { 
        flash[:notice] = 'Thank you for your report. We will investigate this issue.'
        redirect_back(fallback_location: root_path)
      }
    end
  rescue => e
    ActivityLogger.log(:error, "Error report submission failed: #{e.message}", { user_id: current_user&.id })
    
    respond_to do |format|
      format.json { render json: { status: 'error', message: 'Unable to submit report at this time.' }, status: :unprocessable_entity }
      format.html {
        flash[:alert] = 'Unable to submit report at this time. Please try again later.'
        redirect_back(fallback_location: root_path)
      }
    end
  end
  
  private
  
  def log_error_details
    error_context = {
      error_type: @error_type,
      error_code: @error_code,
      request_path: request.path,
      request_method: request.method,
      referrer: request.referrer,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      user_id: current_user&.id,
      session_id: session.id,
      params: filtered_params
    }
    
    case @error_code
    when 404
      # Log 404s as info level for analytics, but track suspicious patterns
      ActivityLogger.log(:info, "Page not found: #{request.path}", error_context)
      track_suspicious_404_pattern(error_context)
      ActivityLogger.track_error_pattern('not_found', error_context)
    when 422
      # Log validation errors
      ActivityLogger.log(:warn, "Unprocessable entity: #{request.path}", error_context)
      ActivityLogger.track_error_pattern('unprocessable_entity', error_context)
    when 500
      # Log server errors as errors and notify
      ActivityLogger.security('system_error', "Internal server error occurred", error_context)
      notify_admin_of_error(error_context)
      ActivityLogger.track_error_pattern('internal_server_error', error_context)
    end
  end
  
  def track_suspicious_404_pattern(context)
    # Track repeated 404s from same IP/user for security monitoring
    return unless context[:ip_address] || context[:user_id]
    
    cache_key = "404_tracking_#{context[:ip_address]}_#{context[:user_id]}"
    count = Rails.cache.read(cache_key) || 0
    count += 1
    
    Rails.cache.write(cache_key, count, expires_in: 1.hour)
    
    # Flag suspicious activity if too many 404s
    if count > 10
      ActivityLogger.security('suspicious_activity', 
        "Excessive 404 requests detected", 
        context.merge(request_count: count)
      )
    end
  end
  
  def notify_admin_of_error(context)
    # Queue notification for admins about server errors
    if defined?(AdminMailer) && Rails.env.production?
      AdminMailer.error_notification(context).deliver_later
    end
  end
  
  def filtered_params
    # Remove sensitive parameters from logging
    request.filtered_parameters.except('authenticity_token', 'commit')
  end
end