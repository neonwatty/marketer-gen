module UserSessionsHelper
  def parse_user_agent(user_agent_string)
    return "Unknown" if user_agent_string.blank?
    
    # Simple user agent parsing - in production, consider using a gem like 'browser'
    case user_agent_string
    when /Chrome\/(\d+)/
      "Chrome #{$1}"
    when /Safari\/(\d+)/
      "Safari"
    when /Firefox\/(\d+)/
      "Firefox #{$1}"
    when /Edge\/(\d+)/
      "Edge #{$1}"
    when /MSIE (\d+)/
      "Internet Explorer #{$1}"
    else
      user_agent_string.truncate(50)
    end
  end
end
