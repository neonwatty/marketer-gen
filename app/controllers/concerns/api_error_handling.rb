module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
    rescue_from StandardError, with: :handle_internal_error
  end

  private

  def handle_not_found(exception)
    render_error(
      message: 'Resource not found',
      status: :not_found,
      code: 'RESOURCE_NOT_FOUND'
    )
  end

  def handle_validation_error(exception)
    render_error(
      message: 'Validation failed',
      errors: exception.record.errors.as_json,
      status: :unprocessable_entity,
      code: 'VALIDATION_ERROR'
    )
  end

  def handle_parameter_missing(exception)
    render_error(
      message: "Required parameter missing: #{exception.param}",
      status: :bad_request,
      code: 'PARAMETER_MISSING'
    )
  end

  def handle_unauthorized(exception)
    render_error(
      message: 'Access denied',
      status: :forbidden,
      code: 'ACCESS_DENIED'
    )
  end

  def handle_internal_error(exception)
    # Log the error for debugging
    Rails.logger.error "API Error: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if Rails.env.development?

    # Don't expose internal error details in production
    message = Rails.env.production? ? 'Internal server error' : exception.message
    
    render_error(
      message: message,
      status: :internal_server_error,
      code: 'INTERNAL_ERROR'
    )
  end
end