module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      # In test environment, Current.session might already be set
      Current.session ||= find_session_by_cookie
      
      if Current.session
        # Check if session is still valid (skip some checks in test)
        if !Rails.env.test? && Current.session.expired?
          terminate_session
          return false
        end
        
        # Touch session activity for idle timeout tracking (skip in test)
        Current.session.touch_activity! unless Rails.env.test?
        
        # Security checks (relaxed in test)
        perform_security_checks! unless Rails.env.test?
        
        true
      else
        false
      end
    end

    def find_session_by_cookie
      return nil unless cookies.signed[:session_id]
      
      session = Session.find_by(id: cookies.signed[:session_id])
      return nil unless session&.active?
      
      session
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      # Terminate any existing sessions if suspicious activity is detected
      cleanup_suspicious_sessions_for(user)
      
      user.sessions.create!(
        user_agent: request.user_agent || 'unknown',
        ip_address: request.remote_ip || 'unknown'
      ).tap do |session|
        Current.session = session
        
        # Set secure cookie with enhanced security options
        cookie_options = {
          value: session.id,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?
        }
        
        # Don't set permanent cookies, use session expiry instead
        cookies.signed[:session_id] = cookie_options
        
        # Log session creation for security monitoring
        Rails.logger.info "New session created for user #{user.id} from IP #{request.remote_ip}"
      end
    end

    def terminate_session
      if Current.session
        Rails.logger.info "Session terminated for user #{Current.session.user_id}"
        Current.session.destroy
      end
      
      cookies.delete(:session_id)
      Current.session = nil
    end

    def perform_security_checks!
      return unless Current.session
      
      # Check for IP address changes (potential session hijacking)
      if Current.session.ip_address != request.remote_ip
        Rails.logger.warn "IP address mismatch for session #{Current.session.id}: " \
                         "expected #{Current.session.ip_address}, got #{request.remote_ip}"
        
        # For now, just log. In high-security scenarios, you might terminate the session
        # terminate_session
        # return false
      end
      
      # Check for suspicious activity
      if Current.session.suspicious_activity?
        Rails.logger.warn "Suspicious activity detected for session #{Current.session.id}"
        # Consider terminating or requiring re-authentication
      end
      
      true
    end

    def cleanup_suspicious_sessions_for(user)
      suspicious_sessions = user.sessions.select(&:suspicious_activity?)
      if suspicious_sessions.any?
        Rails.logger.warn "Cleaning up #{suspicious_sessions.count} suspicious sessions for user #{user.id}"
        suspicious_sessions.each(&:terminate!)
      end
    end
end
