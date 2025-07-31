class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include RailsAdminAuditable
  include ActivityTracker
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Error handling for production
  unless Rails.env.development? || Rails.env.test?
    rescue_from StandardError, with: :handle_internal_server_error
    rescue_from ActionController::RoutingError, with: :handle_not_found
    rescue_from ActionController::UnknownController, with: :handle_not_found
    rescue_from AbstractController::ActionNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  end
  
  # Pundit authorization error handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_token
  rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
  
  private
  
  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
  
  def handle_not_found(exception = nil)
    log_error_with_context(exception, :not_found) if exception
    
    respond_to do |format|
      format.html { render template: 'errors/404', status: :not_found }
      format.json { render json: { error: 'Not found', status: 404 }, status: :not_found }
      format.all { render plain: 'Not found', status: :not_found }
    end
  end
  
  def handle_invalid_token(exception = nil)
    log_error_with_context(exception, :invalid_token) if exception
    
    respond_to do |format|
      format.html { 
        flash[:alert] = "Your session has expired. Please try again."
        redirect_to request.referrer || root_path
      }
      format.json { render json: { error: 'Invalid authenticity token', status: 422 }, status: :unprocessable_entity }
    end
  end
  
  def handle_unpermitted_parameters(exception = nil)
    log_error_with_context(exception, :unpermitted_parameters) if exception
    
    respond_to do |format|
      format.html { render template: 'errors/422', status: :unprocessable_entity }
      format.json { render json: { error: 'Unpermitted parameters', status: 422 }, status: :unprocessable_entity }
    end
  end
  
  def handle_internal_server_error(exception = nil)
    log_error_with_context(exception, :internal_server_error) if exception
    
    # Notify error tracking service (Sentry, Rollbar, etc.)
    notify_error_service(exception) if exception && Rails.env.production?
    
    respond_to do |format|
      format.html { render template: 'errors/500', status: :internal_server_error }
      format.json { render json: { error: 'Internal server error', status: 500 }, status: :internal_server_error }
      format.all { render plain: 'Internal server error', status: :internal_server_error }
    end
  end
  
  def log_error_with_context(exception, error_type)
    error_context = {
      exception_class: exception.class.name,
      exception_message: exception.message,
      backtrace: exception.backtrace&.first(10),
      request_path: request.path,
      request_method: request.method,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      user_id: current_user&.id,
      session_id: session.id,
      params: request.filtered_parameters.except('authenticity_token', 'commit'),
      referrer: request.referrer
    }
    
    case error_type
    when :not_found
      ActivityLogger.log(:info, "#{exception.class}: #{exception.message}", error_context)
    when :invalid_token, :unpermitted_parameters
      ActivityLogger.security('authentication_failure', exception.message, error_context)
    when :internal_server_error
      ActivityLogger.security('system_error', "#{exception.class}: #{exception.message}", error_context)
    end
  end
  
  def notify_error_service(exception)
    # Integration point for error tracking services
    # Example: Sentry.capture_exception(exception)
    Rails.logger.error "CRITICAL ERROR: #{exception.class} - #{exception.message}\n#{exception.backtrace&.join("\n")}"
  end
end
