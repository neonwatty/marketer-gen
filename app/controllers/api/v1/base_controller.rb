class Api::V1::BaseController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # Use JSON format by default
  before_action :set_default_format
  
  # Include API-specific concerns
  include ApiAuthentication
  include ApiErrorHandling
  include ApiPagination
  
  private
  
  def set_default_format
    request.format = :json unless params[:format]
  end
  
  # API-specific success response format
  def render_success(data: nil, message: nil, status: :ok, meta: {})
    response_body = { success: true }
    response_body[:data] = data if data
    response_body[:message] = message if message
    response_body[:meta] = meta if meta.any?
    
    render json: response_body, status: status
  end
  
  # API-specific error response format
  def render_error(message: nil, errors: {}, status: :unprocessable_entity, code: nil)
    response_body = { 
      success: false,
      message: message || 'An error occurred'
    }
    response_body[:code] = code if code
    response_body[:errors] = errors if errors.any?
    
    render json: response_body, status: status
  end
  
  # Ensure user can only access their own resources
  def ensure_user_resource_access(resource)
    unless resource&.user == current_user
      render_error(message: 'Resource not found', status: :not_found)
      return false
    end
    true
  end
end