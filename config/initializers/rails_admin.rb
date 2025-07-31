# Skip Rails Admin configuration in test environment to avoid CSS compilation issues
if Rails.env.test?
  return
end

# Load custom actions first
require Rails.root.join('config/initializers/rails_admin_custom_actions.rb')

RailsAdmin.config do |config|
  config.asset_source = :importmap
  
  # Include custom helpers
  config.included_models = ["User", "Session", "AdminAuditLog", "Activity"]

  ### Popular gems integration

  ## == Custom Authentication ==
  config.parent_controller = "::ApplicationController"
  
  config.authenticate_with do
    unless current_user&.admin?
      redirect_to main_app.new_session_path, alert: "Access denied. Admin privileges required."
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
    bulk_unlock
    system_maintenance

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
      field :role
      field :company
      field :job_title
      field :created_at
    end
    
    # Edit form configuration
    edit do
      field :email_address
      field :full_name
      field :role, :enum do
        enum do
          User.roles.map { |k, v| [k.humanize.titleize, k] }
        end
      end
      field :company
      field :job_title
    end
  end
  
  # Session model configuration
  config.model 'Session' do
    visible false # Hide from navigation but still manageable
  end
  
  # Admin Audit Log configuration
  config.model 'AdminAuditLog' do
    navigation_label 'System'
    label 'Audit Logs'
    label_plural 'Audit Logs'
    
    list do
      field :id
      field :user
      field :action
      field :auditable_type
      field :auditable_id
      field :ip_address
      field :created_at
    end
    
    # Disable editing and creation for read-only model
  end
  
  # Activity model configuration
  config.model 'Activity' do
    navigation_label 'System'
    label 'User Activities'
    label_plural 'User Activities'
    
    list do
      field :id
      field :user
      field :action
      field :controller
      field :ip_address
      field :suspicious
      field :response_status
      field :occurred_at
    end
    
    # Read-only model
  end
end
