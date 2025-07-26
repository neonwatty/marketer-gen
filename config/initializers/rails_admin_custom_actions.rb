require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdmin
  module Config
    module Actions
      class Suspend < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        
        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(User) && !bindings[:object].suspended? && bindings[:object] != bindings[:controller].current_user
        end
        
        register_instance_option :member do
          true
        end
        
        register_instance_option :http_methods do
          [:get, :post]
        end
        
        register_instance_option :route_fragment do
          'suspend'
        end
        
        register_instance_option :controller do
          proc do
            if request.get?
              render @action.template_name
            elsif request.post?
              reason = params[:suspension_reason]
              if reason.present?
                @object.suspend!(reason: reason, by: current_user)
                AdminAuditLog.log_action(
                  user: current_user,
                  action: "suspended_user",
                  auditable: @object,
                  changes: { suspension_reason: reason },
                  request: request
                )
                flash[:success] = "User #{@object.email_address} has been suspended."
              else
                flash[:error] = "Please provide a suspension reason."
              end
              redirect_to back_or_index
            end
          end
        end
        
        register_instance_option :link_icon do
          'fa fa-ban'
        end
        
        register_instance_option :pjax? do
          false
        end
      end
      
      class Unsuspend < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        
        register_instance_option :visible? do
          authorized? && bindings[:object].is_a?(User) && bindings[:object].suspended?
        end
        
        register_instance_option :member do
          true
        end
        
        register_instance_option :http_methods do
          [:get, :post]
        end
        
        register_instance_option :route_fragment do
          'unsuspend'
        end
        
        register_instance_option :controller do
          proc do
            if request.get?
              render @action.template_name
            elsif request.post?
              @object.unsuspend!
              AdminAuditLog.log_action(
                user: current_user,
                action: "unsuspended_user",
                auditable: @object,
                changes: { action: "account_reinstated" },
                request: request
              )
              flash[:success] = "User #{@object.email_address} has been unsuspended."
              redirect_to back_or_index
            end
          end
        end
        
        register_instance_option :link_icon do
          'fa fa-check-circle'
        end
        
        register_instance_option :pjax? do
          false
        end
      end
    end
  end
end