# frozen_string_literal: true

# Base class for application services
# Provides common functionality and includes LLM service helper
class ApplicationService
  include LlmServiceHelper

  # Class method to call service
  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  # Instance method that must be implemented by subclasses
  def call
    raise NotImplementedError, "#{self.class} must implement #call method"
  end

  # Helper method for logging service calls
  def log_service_call(service_name, params = {})
    Rails.logger.info "Service Call: #{service_name} with params: #{params.inspect}"
  end

  # Helper method for handling service errors
  def handle_service_error(error, context = {})
    Rails.logger.error "Service Error in #{self.class}: #{error.message}"
    Rails.logger.error "Context: #{context.inspect}" if context.any?
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Return a structured error response
    {
      success: false,
      error: error.message,
      context: context
    }
  end

  # Helper method for successful service responses
  def success_response(data = {})
    {
      success: true,
      data: data
    }
  end

  protected
end