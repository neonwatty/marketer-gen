module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_user
  end

  private

  def authenticate_api_user
    # Use the existing session-based authentication for API endpoints
    unless authenticated?
      render_api_authentication_error
      return false
    end

    # Check if user account is active
    if current_user.locked?
      render_api_account_locked_error
      return false
    end

    true
  end

  def render_api_authentication_error
    render json: {
      success: false,
      message: "Authentication required",
      code: "AUTHENTICATION_REQUIRED"
    }, status: :unauthorized
  end

  def render_api_account_locked_error
    render json: {
      success: false,
      message: "Account is locked",
      code: "ACCOUNT_LOCKED",
      details: current_user.lock_reason
    }, status: :forbidden
  end

  # Override parent class methods to return JSON instead of redirects
  def request_authentication
    render_api_authentication_error
  end
end
