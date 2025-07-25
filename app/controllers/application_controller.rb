class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include RailsAdminAuditable
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Pundit authorization error handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  private
  
  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
