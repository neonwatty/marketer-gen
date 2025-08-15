# frozen_string_literal: true

# Service class for logging admin activities
class AdminActivityLogger
  attr_reader :admin_user, :action, :resource, :details

  def initialize(admin_user:, action:, resource:, details: {})
    @admin_user = admin_user
    @action = action
    @resource = resource
    @details = details
  end

  def log!
    Rails.logger.info build_log_message
    
    # Could also save to database or external audit system
    # AuditLog.create!(
    #   admin_user: admin_user,
    #   action: action,
    #   resource_type: resource.class.name,
    #   resource_id: resource.id,
    #   details: details,
    #   ip_address: details[:ip_address],
    #   user_agent: details[:user_agent]
    # )
  end

  class << self
    def log_user_action(admin_user:, action:, target_user:, request: nil)
      details = extract_request_details(request) if request
      
      new(
        admin_user: admin_user,
        action: action,
        resource: target_user,
        details: details || {}
      ).log!
    end

    def log_session_action(admin_user:, action:, session:, request: nil)
      details = extract_request_details(request) if request
      details ||= {}
      details[:session_ip] = session.ip_address
      details[:session_user] = session.user.email_address

      new(
        admin_user: admin_user,
        action: action,
        resource: session,
        details: details
      ).log!
    end

    def log_model_action(admin_user:, action:, resource:, request: nil)
      details = extract_request_details(request) if request

      new(
        admin_user: admin_user,
        action: action,
        resource: resource,
        details: details || {}
      ).log!
    end

    private

    def extract_request_details(request)
      return {} unless request

      {
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        timestamp: Time.current.iso8601
      }
    end
  end

  private

  def build_log_message
    message_parts = [
      "[ADMIN_AUDIT]",
      "User: #{admin_user.email_address}",
      "Action: #{action.upcase}",
      "Resource: #{resource.class.name}##{resource.id}"
    ]

    if resource.respond_to?(:email_address)
      message_parts << "Target: #{resource.email_address}"
    end

    if details[:ip_address]
      message_parts << "IP: #{details[:ip_address]}"
    end

    message_parts.join(" | ")
  end
end