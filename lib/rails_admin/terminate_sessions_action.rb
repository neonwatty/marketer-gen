# frozen_string_literal: true

# Custom Rails Admin action to terminate user sessions
module RailsAdmin
  class TerminateSessionsAction < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(User) && bindings[:object].sessions.any?
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            @user = @object
            
            if request.get?
              # Show confirmation page
              render template: 'rails_admin/main/terminate_sessions'
            elsif request.post?
              # Perform the termination
              session_count = @user.sessions.count
              @user.terminate_all_sessions!
              
              # Log the admin action
              AdminActivityLogger.log_user_action(
                admin_user: current_user,
                action: 'terminate_all_sessions',
                target_user: @user,
                request: request
              )
              
              redirect_to(back_or_index, notice: "Terminated #{session_count} sessions for #{@user.email_address}")
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-ban'
        end

        register_instance_option :authorization_key do
          :terminate_sessions
        end
  end
end