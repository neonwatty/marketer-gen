class DemosController < ApplicationController
  include Authentication
  
  # Allow anonymous access to demos for broader reach
  skip_before_action :require_authentication, only: [:index, :start_tour]
  
  def index
    @workflows = TourGeneratorService::WORKFLOW_CONFIGS
    @user_progress = current_user ? load_user_progress : {}
  end
  
  def start_tour
    workflow_key = params[:workflow]
    
    unless TourGeneratorService::WORKFLOW_CONFIGS.key?(workflow_key)
      return render json: { success: false, error: 'Invalid workflow' }, status: :bad_request
    end
    
    begin
      tour_config = TourGeneratorService.generate(workflow_key)
      
      # Track demo start (for analytics)
      track_demo_event(workflow_key, 'started') if current_user
      
      render json: {
        success: true,
        tour_config: tour_config,
        workflow_info: TourGeneratorService::WORKFLOW_CONFIGS[workflow_key]
      }
    rescue => e
      Rails.logger.error "Failed to generate tour for #{workflow_key}: #{e.message}"
      render json: { success: false, error: 'Failed to generate tour' }, status: :internal_server_error
    end
  end
  
  def track_completion
    workflow_key = params[:workflow_key]
    event = params[:event] # 'started', 'completed', 'exited'
    
    # For now, just log the analytics - we'll add database tracking later
    Rails.logger.info "Demo #{event}: #{workflow_key} by #{current_user&.id || 'anonymous'}"
    
    render json: { success: true }
  end
  
  private
  
  def load_user_progress
    # Placeholder for user progress tracking - will implement with database models later
    {}
  end
  
  def track_demo_event(workflow_key, event)
    # Placeholder for demo event tracking - will implement with database models later
    Rails.logger.info "Demo #{event}: #{workflow_key} by #{current_user&.id || 'anonymous'}"
  end
end
