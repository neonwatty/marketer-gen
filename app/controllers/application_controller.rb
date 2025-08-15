class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  
  # Security configurations
  protect_from_forgery with: :exception, prepend: true
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Security headers
  before_action :set_security_headers
  
  # Rate limiting (we'll implement this next)
  before_action :check_rate_limit, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parameter_parse_error
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error

  private

  def current_user
    Current.user
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back_or_to(root_path)
  end

  def handle_parameter_parse_error
    Rails.logger.warn "Parameter parse error from IP: #{request.remote_ip}"
    head :bad_request
  end

  def handle_csrf_error
    Rails.logger.warn "CSRF token verification failed from IP: #{request.remote_ip}"
    
    if request.xhr?
      render json: { error: 'Invalid authenticity token' }, status: :unprocessable_entity
    else
      redirect_to new_session_path, alert: 'Security verification failed. Please try again.'
    end
  end

  def set_security_headers
    # X-Frame-Options: Prevent clickjacking
    response.headers['X-Frame-Options'] = 'DENY'
    
    # X-Content-Type-Options: Prevent MIME sniffing
    response.headers['X-Content-Type-Options'] = 'nosniff'
    
    # X-XSS-Protection: Enable XSS filtering
    response.headers['X-XSS-Protection'] = '1; mode=block'
    
    # Referrer-Policy: Control referrer information
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    
    # Strict-Transport-Security: Force HTTPS (only in production)
    if Rails.env.production?
      response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    end
    
    # X-Permitted-Cross-Domain-Policies: Restrict cross-domain policies
    response.headers['X-Permitted-Cross-Domain-Policies'] = 'none'
  end

  def check_rate_limit
    # Simple rate limiting implementation
    client_ip = request.remote_ip
    cache_key = "rate_limit:#{client_ip}"
    
    # Allow 100 requests per minute per IP
    current_count = Rails.cache.read(cache_key) || 0
    
    if current_count >= 100
      Rails.logger.warn "Rate limit exceeded for IP: #{client_ip}"
      
      if request.xhr?
        render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
      else
        render plain: 'Rate limit exceeded. Please try again later.', status: :too_many_requests
      end
      return
    end
    
    # Increment counter with 1-minute expiry
    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.minute)
  end

  def devise_controller?
    # Helper method for rate limiting exclusion
    false # We're not using Devise
  end
end
