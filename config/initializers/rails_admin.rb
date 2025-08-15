# Load custom actions
# require Rails.root.join('lib', 'rails_admin', 'terminate_sessions_action')

RailsAdmin.config do |config|
  config.asset_source = :importmap
  
  # Set main app name for dashboard
  config.main_app_name = ['Dashboard', 'Admin']

  ### Popular gems integration

  ## == Authentication ==
  config.authenticate_with do
    # Check if user is authenticated by looking for a valid session
    session_id = cookies.signed[:session_id]
    current_session = session_id ? Session.find_by(id: session_id) : nil
    
    unless current_session&.active?
      redirect_to '/sessions/new'
    end
  end

  config.current_user_method do
    session_id = cookies.signed[:session_id]
    current_session = session_id ? Session.find_by(id: session_id) : nil
    current_session&.active? ? current_session.user : nil
  end

  ## == Authorization ==
  config.authorize_with do
    # Get current user from session
    session_id = cookies.signed[:session_id]
    current_session = session_id ? Session.find_by(id: session_id) : nil
    user = current_session&.active? ? current_session.user : nil
    
    # Only allow admin users
    unless user&.admin?
      redirect_to '/', alert: 'You are not authorized to access this area.'
    end
  end

  ## == Pundit ==
  # Using manual authorization instead
  # config.authorize_with :pundit

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/railsadminteam/rails_admin/wiki/Base-configuration

  ## == Gravatar integration ==
  ## To disable Gravatar integration in Navigation Bar set to false
  # config.show_gravatar = true

  ## == Model Configuration ==
  config.included_models = %w[User Session Journey JourneyStep JourneyTemplate]

  ## == Actions Configuration ==
  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new do
      except %w[Session]         # Don't allow creating sessions through admin
    end
    export
    bulk_delete do
      except %w[Session]         # Protect sessions from bulk delete
    end
    show
    edit do
      except %w[Session]         # Sessions shouldn't be edited
    end
    delete
    show_in_app

    # Custom actions
    # terminate_sessions do
    #   only %w[User]              # Only available for User model
    # end

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end

  ## == Model-specific configurations ==
  
  # User model configuration
  config.model 'User' do
    list do
      field :id
      field :email_address
      field :first_name
      field :last_name
      field :role
      field :created_at
      field :sessions do
        label 'Active Sessions'
        formatted_value do
          bindings[:object].active_sessions.count
        end
      end
    end

    edit do
      field :email_address
      field :first_name
      field :last_name
      field :role, :enum do
        enum do
          User::ROLES.map { |role| [role.humanize, role] }
        end
      end
      field :phone
      field :company
      field :bio
      field :notification_preferences, :text do
        help 'JSON format: {"email_notifications": true, "journey_updates": false}'
      end
    end

    show do
      field :id
      field :email_address
      field :first_name
      field :last_name
      field :full_name
      field :role
      field :phone
      field :company
      field :bio
      field :notification_preferences
      field :created_at
      field :updated_at
      field :sessions
      field :journeys
    end
  end

  # Session model configuration
  config.model 'Session' do
    list do
      field :id
      field :user
      field :ip_address
      field :user_agent do
        formatted_value do
          bindings[:object].user_agent.truncate(50)
        end
      end
      field :updated_at, :datetime do
        label 'Last Activity'
      end
      field :created_at
    end

    show do
      field :id
      field :user
      field :ip_address
      field :user_agent
      field :updated_at, :datetime do
        label 'Last Activity'
      end
      field :created_at
      field :updated_at
    end
  end

  # Journey model configuration
  config.model 'Journey' do
    list do
      field :id
      field :name
      field :user
      field :status
      field :created_at
    end

    edit do
      field :name
      field :description
      field :user
      field :status, :enum do
        enum do
          [['Draft', 'draft'], ['Published', 'published'], ['Archived', 'archived']]
        end
      end
    end
  end

  # Journey Step model configuration
  config.model 'JourneyStep' do
    list do
      field :id
      field :title
      field :journey
      field :sequence_order
      field :step_type
      field :created_at
    end

    edit do
      field :title
      field :description
      field :journey
      field :sequence_order
      field :step_type
      field :content
      field :metadata
    end
  end
end
