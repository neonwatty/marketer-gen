# Load custom actions first
require Rails.root.join('config/initializers/rails_admin_custom_actions.rb')

RailsAdmin.config do |config|
  config.asset_source = :importmap
  
  # Include custom helpers
  config.included_models = ["User", "Session", "AdminAuditLog", "Activity"]

  ### Popular gems integration

  ## == Custom Authentication ==
  config.parent_controller = "::RailsAdmin::ApplicationController"
  
  config.authenticate_with do
    unless current_user
      redirect_to main_app.new_session_path, alert: "Please sign in to access the admin area."
    end
  end
  
  config.current_user_method(&:current_user)

  ## == Pundit ==
  config.authorize_with :pundit

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/railsadminteam/rails_admin/wiki/Base-configuration

  ## == Gravatar integration ==
  ## To disable Gravatar integration in Navigation Bar set to false
  # config.show_gravatar = true

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app
    
    # Custom actions
    suspend
    unsuspend

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end
  
  # Model configurations
  config.model 'User' do
    # List view configuration
    list do
      field :id
      field :email_address
      field :full_name
      field :role do
        pretty_value do
          bindings[:object].role.humanize.titleize
        end
      end
      field :company
      field :job_title
      field :suspended_at do
        label "Status"
        pretty_value do
          if bindings[:object].suspended?
            bindings[:view].content_tag(:span, "Suspended", class: "label label-danger")
          elsif bindings[:object].locked?
            bindings[:view].content_tag(:span, "Locked", class: "label label-warning")
          else
            bindings[:view].content_tag(:span, "Active", class: "label label-success")
          end
        end
      end
      field :created_at
    end
    
    # Show view configuration
    show do
      group :basic_info do
        label "Basic Information"
        field :id
        field :email_address
        field :full_name
        field :role
        field :display_name do
          label "Display Name"
          pretty_value do
            bindings[:object].display_name
          end
        end
      end
      
      group :profile do
        label "Profile Information"
        field :bio
        field :phone_number
        field :company
        field :job_title
        field :location
        field :timezone
        field :avatar do
          pretty_value do
            if bindings[:object].avatar.attached?
              bindings[:view].tag.img(src: bindings[:view].main_app.url_for(bindings[:object].avatar), style: "max-width: 200px;")
            else
              "No avatar uploaded"
            end
          end
        end
      end
      
      group :preferences do
        label "Preferences"
        field :marketing_emails
        field :product_updates
        field :security_alerts
      end
      
      group :timestamps do
        label "Timestamps"
        field :created_at
        field :updated_at
      end
      
      group :account_status do
        label "Account Status"
        field :locked_at
        field :lock_reason
        field :suspended_at
        field :suspension_reason
        field :suspended_by do
          pretty_value do
            if bindings[:object].suspended_by
              bindings[:view].link_to(bindings[:object].suspended_by.email_address, 
                bindings[:view].rails_admin.show_path(model_name: 'user', id: bindings[:object].suspended_by.id))
            else
              "-"
            end
          end
        end
      end
    end
    
    # Edit form configuration
    edit do
      group :basic_info do
        label "Basic Information"
        field :email_address
        field :full_name
        field :role, :enum do
          enum do
            User.roles.map { |k, v| [k.humanize.titleize, k] }
          end
        end
      end
      
      group :authentication do
        label "Authentication"
        field :password do
          help "Leave blank if you don't want to change it"
        end
        field :password_confirmation do
          help "Leave blank if you don't want to change it"
        end
      end
      
      group :profile do
        label "Profile Information"
        field :bio
        field :phone_number
        field :company
        field :job_title
        field :location
        field :timezone do
          partial "rails_admin/timezone_select"
        end
        field :avatar, :active_storage
      end
      
      group :preferences do
        label "Email Preferences"
        field :marketing_emails
        field :product_updates
        field :security_alerts
      end
    end
    
    # Export configuration
    export do
      field :id
      field :email_address
      field :full_name
      field :role
      field :company
      field :job_title
      field :created_at
    end
  end
  
  # Session model configuration
  config.model 'Session' do
    visible false # Hide from navigation but still manageable
    
    list do
      field :id
      field :user
      field :user_agent
      field :ip_address
      field :expires_at
      field :last_active_at
      field :created_at
    end
  end
  
  # Admin Audit Log configuration
  config.model 'AdminAuditLog' do
    navigation_label 'System'
    label 'Audit Logs'
    label_plural 'Audit Logs'
    weight 100
    
    # Read-only model - no creation/editing allowed
    configure :created_at do
      visible true
    end
    
    list do
      field :id
      field :user do
        pretty_value do
          bindings[:object].user&.email_address
        end
      end
      field :action do
        pretty_value do
          bindings[:object].action.humanize
        end
      end
      field :auditable_type
      field :auditable_id
      field :ip_address
      field :created_at
      
      sort_by :created_at
    end
    
    show do
      field :id
      field :user
      field :action
      field :auditable_type
      field :auditable_id
      field :change_details do
        pretty_value do
          if bindings[:object].change_details.present?
            bindings[:view].content_tag(:pre, JSON.pretty_generate(bindings[:object].parsed_changes))
          else
            "No changes recorded"
          end
        end
      end
      field :ip_address
      field :user_agent
      field :created_at
    end
    
    # Disable editing and creation
    configure do
      edit do
        visible false
      end
      new do
        visible false
      end
      delete do
        visible false
      end
      bulk_delete do
        visible false
      end
    end
  end
  
  # Activity model configuration
  config.model 'Activity' do
    navigation_label 'System'
    label 'User Activities'
    label_plural 'User Activities'
    weight 90
    
    list do
      field :id
      field :user
      field :action
      field :controller
      field :ip_address
      field :suspicious do
        pretty_value do
          if bindings[:object].suspicious?
            bindings[:view].content_tag(:span, "Yes", class: "label label-danger")
          else
            bindings[:view].content_tag(:span, "No", class: "label label-default")
          end
        end
      end
      field :response_status
      field :response_time do
        pretty_value do
          if bindings[:object].response_time
            "#{(bindings[:object].response_time * 1000).round(2)} ms"
          else
            "-"
          end
        end
      end
      field :occurred_at
      
      sort_by :occurred_at
    end
    
    show do
      field :id
      field :user
      field :action
      field :controller
      field :request_path
      field :request_method
      field :ip_address
      field :user_agent
      field :device_type
      field :browser_name
      field :os_name
      field :session_id
      field :response_status
      field :response_time do
        pretty_value do
          if bindings[:object].response_time
            "#{(bindings[:object].response_time * 1000).round(2)} ms"
          else
            "-"
          end
        end
      end
      field :suspicious
      field :metadata do
        pretty_value do
          if bindings[:object].metadata.present?
            bindings[:view].content_tag(:pre, JSON.pretty_generate(bindings[:object].metadata))
          else
            "-"
          end
        end
      end
      field :occurred_at
    end
    
    # Read-only model
    configure do
      edit do
        visible false
      end
      new do
        visible false
      end
      delete do
        visible false
      end
    end
  end
end
