require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

module RailsAdmin
  module Config
    module Actions
      # Bulk unlock action for users
      class BulkUnlock < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        
        register_instance_option :visible? do
          authorized? && abstract_model.model_name == "User"
        end
        
        register_instance_option :collection do
          true
        end
        
        register_instance_option :http_methods do
          [:post]
        end
        
        register_instance_option :route_fragment do
          'bulk_unlock'
        end
        
        register_instance_option :controller do
          proc do
            if params[:bulk_ids].present?
              users = User.where(id: params[:bulk_ids]).where.not(locked_at: nil)
              count = 0
              
              users.each do |user|
                user.unlock!
                AdminAuditLog.log_action(
                  user: current_user,
                  action: "bulk_unlocked_user",
                  auditable: user,
                  changes: { bulk_action: true },
                  request: request
                )
                count += 1
              end
              
              flash[:success] = "Successfully unlocked #{count} user(s)."
            else
              flash[:error] = "No users selected for unlocking."
            end
            redirect_to back_or_index
          end
        end
        
        register_instance_option :link_icon do
          'fa fa-unlock'
        end
      end
      
      # System maintenance action
      class SystemMaintenance < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        
        register_instance_option :visible? do
          authorized? && bindings[:controller].current_user&.admin?
        end
        
        register_instance_option :root do
          true
        end
        
        register_instance_option :http_methods do
          [:get, :post]
        end
        
        register_instance_option :route_fragment do
          'system_maintenance'
        end
        
        register_instance_option :controller do
          proc do
            if request.get?
              @cleanup_stats = {
                old_activities: Activity.where("occurred_at < ?", 30.days.ago).count,
                expired_sessions: Session.expired.count,
                old_audit_logs: AdminAuditLog.where("created_at < ?", 90.days.ago).count
              }
              render @action.template_name
            elsif request.post?
              case params[:maintenance_action]
              when 'cleanup_old_activities'
                count = Activity.where("occurred_at < ?", 30.days.ago).delete_all
                flash[:success] = "Deleted #{count} old activity records."
              when 'cleanup_expired_sessions'
                count = Session.expired.delete_all
                flash[:success] = "Deleted #{count} expired sessions."
              when 'cleanup_old_audit_logs'
                count = AdminAuditLog.where("created_at < ?", 90.days.ago).delete_all
                flash[:success] = "Deleted #{count} old audit log records."
              when 'full_cleanup'
                activities = Activity.where("occurred_at < ?", 30.days.ago).delete_all
                sessions = Session.expired.delete_all
                audit_logs = AdminAuditLog.where("created_at < ?", 90.days.ago).delete_all
                flash[:success] = "Cleanup complete: #{activities} activities, #{sessions} sessions, #{audit_logs} audit logs deleted."
              else
                flash[:error] = "Invalid maintenance action."
              end
              
              # Log the maintenance action
              AdminAuditLog.log_action(
                user: current_user,
                action: "system_maintenance",
                changes: { maintenance_action: params[:maintenance_action] },
                request: request
              )
              
              redirect_to back_or_index
            end
          end
        end
        
        register_instance_option :link_icon do
          'fa fa-cogs'
        end
      end
      
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