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
      
      # Create analytics tracking record
      demo_analytic = create_demo_analytic(workflow_key, tour_config)
      
      render json: {
        success: true,
        tour_config: tour_config,
        workflow_info: TourGeneratorService::WORKFLOW_CONFIGS[workflow_key],
        analytics_id: demo_analytic.id
      }
    rescue => e
      Rails.logger.error "Failed to generate tour for #{workflow_key}: #{e.message}"
      render json: { success: false, error: 'Failed to generate tour' }, status: :internal_server_error
    end
  end
  
  def track_completion
    analytics_id = params[:analytics_id]
    event = params[:event] # 'completed', 'exited'
    step_number = params[:step_number]
    step_title = params[:step_title]
    time_spent = params[:time_spent]
    
    demo_analytic = DemoAnalytic.find_by(id: analytics_id)
    
    if demo_analytic
      case event
      when 'step_completed'
        # Track individual step completion
        demo_analytic.demo_progresses.create!(
          step_number: step_number,
          step_title: step_title,
          completed_at: Time.current,
          time_spent: time_spent || 0
        )
        
        # Update overall progress
        demo_analytic.update!(
          steps_completed: demo_analytic.demo_progresses.count
        )
        
      when 'completed'
        # Mark demo as fully completed
        demo_analytic.update!(
          completed_at: Time.current,
          steps_completed: demo_analytic.total_steps
        )
        
      when 'exited'
        # Track early exit - don't mark as completed
        Rails.logger.info "Demo exited early: #{demo_analytic.workflow_key} at step #{step_number}"
      end
    end
    
    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Analytics record not found' }, status: :not_found
  end
  
  private
  
  def load_user_progress
    return {} unless current_user
    
    # Get user's demo completion data
    progress = {}
    current_user.demo_analytics.completed.group(:workflow_key).count.each do |workflow_key, count|
      progress[workflow_key] = {
        completed: count > 0,
        completion_count: count,
        last_completed: current_user.demo_analytics.completed.for_workflow(workflow_key).maximum(:completed_at)
      }
    end
    
    progress
  end
  
  def create_demo_analytic(workflow_key, tour_config)
    DemoAnalytic.create!(
      workflow_key: workflow_key,
      user: current_user,
      started_at: Time.current,
      total_steps: tour_config[:steps]&.length || 0,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
  end
end
