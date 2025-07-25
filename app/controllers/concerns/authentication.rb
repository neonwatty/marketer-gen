module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
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
    
    def current_user
      Current.session&.user
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
      
      if Current.session
        if Current.session.expired? || Current.session.inactive?
          terminate_session
          false
        elsif Current.session.user.locked?
          terminate_session
          redirect_to new_session_path, alert: "Your account has been locked: #{Current.session.user.lock_reason}"
          false
        else
          Current.session.touch_activity!
          true
        end
      else
        false
      end
    end

    def find_session_by_cookie
      Session.active.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user, remember_me: false)
      session_timeout = remember_me ? 30.days : Session::SESSION_TIMEOUT
      
      user.sessions.create!(
        user_agent: request.user_agent, 
        ip_address: request.remote_ip,
        expires_at: session_timeout.from_now
      ).tap do |session|
        Current.session = session
        
        if remember_me
          cookies.signed.permanent[:session_id] = { 
            value: session.id, 
            httponly: true, 
            same_site: :lax,
            secure: Rails.env.production?
          }
        else
          cookies.signed[:session_id] = { 
            value: session.id, 
            httponly: true, 
            same_site: :lax,
            secure: Rails.env.production?,
            expires: session_timeout.from_now
          }
        end
      end
    end

    def terminate_session
      Current.session.destroy if Current.session
      cookies.delete(:session_id)
      Current.session = nil
    end
end
