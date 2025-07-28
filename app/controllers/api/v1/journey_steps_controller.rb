class Api::V1::JourneyStepsController < Api::V1::BaseController
  before_action :set_journey
  before_action :set_step, only: [:show, :update, :destroy, :reorder, :duplicate, :execute]
  
  # GET /api/v1/journeys/:journey_id/steps
  def index
    steps = @journey.journey_steps.includes(:transitions_from, :transitions_to)
    
    # Apply filters
    steps = steps.where(stage: params[:stage]) if params[:stage].present?
    steps = steps.where(step_type: params[:step_type]) if params[:step_type].present?
    steps = steps.where(status: params[:status]) if params[:status].present?
    
    # Apply sorting
    case params[:sort_by]
    when 'position'
      steps = steps.order(:position)
    when 'stage'
      steps = steps.order(:stage, :position)
    when 'created_at'
      steps = steps.order(:created_at)
    else
      steps = steps.order(:position)
    end
    
    paginate_and_render(steps, serializer: method(:serialize_step_summary))
  end
  
  # GET /api/v1/journeys/:journey_id/steps/:id
  def show
    render_success(data: serialize_step_detail(@step))
  end
  
  # POST /api/v1/journeys/:journey_id/steps
  def create
    step = @journey.journey_steps.build(step_params)
    
    # Set position if not provided
    if step.position.nil?
      max_position = @journey.journey_steps.maximum(:position) || 0
      step.position = max_position + 1
    end
    
    if step.save
      render_success(
        data: serialize_step_detail(step),
        message: 'Step created successfully',
        status: :created
      )
    else
      render_error(
        message: 'Failed to create step',
        errors: step.errors.as_json
      )
    end
  end
  
  # PUT /api/v1/journeys/:journey_id/steps/:id
  def update
    if @step.update(step_params)
      render_success(
        data: serialize_step_detail(@step),
        message: 'Step updated successfully'
      )
    else
      render_error(
        message: 'Failed to update step',
        errors: @step.errors.as_json
      )
    end
  end
  
  # DELETE /api/v1/journeys/:journey_id/steps/:id
  def destroy
    @step.destroy!
    render_success(message: 'Step deleted successfully')
  end
  
  # PATCH /api/v1/journeys/:journey_id/steps/:id/reorder
  def reorder
    new_position = params[:position].to_i
    
    if new_position > 0
      @step.update!(position: new_position)
      render_success(
        data: serialize_step_detail(@step),
        message: 'Step reordered successfully'
      )
    else
      render_error(message: 'Invalid position')
    end
  end
  
  # POST /api/v1/journeys/:journey_id/steps/:id/duplicate
  def duplicate
    begin
      new_step = @step.dup
      new_step.name = "#{@step.name} (Copy)"
      
      # Set new position
      max_position = @journey.journey_steps.maximum(:position) || 0
      new_step.position = max_position + 1
      
      new_step.save!
      
      render_success(
        data: serialize_step_detail(new_step),
        message: 'Step duplicated successfully',
        status: :created
      )
    rescue => e
      render_error(message: "Failed to duplicate step: #{e.message}")
    end
  end
  
  # POST /api/v1/journeys/:journey_id/steps/:id/execute
  def execute
    execution_params = params.permit(:user_data, metadata: {})
    
    begin
      # This would integrate with the journey execution engine
      execution_result = execute_step(@step, execution_params)
      
      render_success(
        data: execution_result,
        message: 'Step executed successfully'
      )
    rescue => e
      render_error(message: "Failed to execute step: #{e.message}")
    end
  end
  
  # GET /api/v1/journeys/:journey_id/steps/:id/transitions
  def transitions
    transitions_from = @step.transitions_from.includes(:to_step)
    transitions_to = @step.transitions_to.includes(:from_step)
    
    transitions_data = {
      outgoing: transitions_from.map { |t| serialize_transition(t) },
      incoming: transitions_to.map { |t| serialize_transition(t) }
    }
    
    render_success(data: transitions_data)
  end
  
  # POST /api/v1/journeys/:journey_id/steps/:id/transitions
  def create_transition
    transition_params = params.require(:transition).permit(:to_step_id, :condition_type, :condition_data, :weight, metadata: {})
    
    to_step = @journey.journey_steps.find(transition_params[:to_step_id])
    
    transition = @step.transitions_from.build(transition_params.merge(to_step: to_step))
    
    if transition.save
      render_success(
        data: serialize_transition(transition),
        message: 'Transition created successfully',
        status: :created
      )
    else
      render_error(
        message: 'Failed to create transition',
        errors: transition.errors.as_json
      )
    end
  end
  
  # GET /api/v1/journeys/:journey_id/steps/:id/analytics
  def analytics
    days = [params[:days].to_i, 1].max
    days = [days, 365].min
    
    # Get step execution analytics
    executions = @step.step_executions
      .where(created_at: days.days.ago..Time.current)
      .includes(:journey_execution)
    
    analytics_data = {
      execution_count: executions.count,
      completion_rate: calculate_step_completion_rate(executions),
      average_duration: calculate_average_duration(executions),
      success_rate: calculate_step_success_rate(executions),
      conversion_metrics: calculate_step_conversions(executions),
      engagement_metrics: calculate_step_engagement(executions)
    }
    
    render_success(data: analytics_data)
  end
  
  private
  
  def set_journey
    @journey = current_user.journeys.find(params[:journey_id])
  end
  
  def set_step
    @step = @journey.journey_steps.find(params[:id])
  end
  
  def step_params
    params.require(:step).permit(
      :name, :description, :step_type, :stage, :position, :timing,
      :status, :trigger_conditions, :success_criteria,
      content: {}, metadata: {}, settings: {}
    )
  end
  
  def serialize_step_summary(step)
    {
      id: step.id,
      name: step.name,
      description: step.description,
      step_type: step.step_type,
      stage: step.stage,
      position: step.position,
      status: step.status,
      timing: step.timing,
      created_at: step.created_at,
      updated_at: step.updated_at
    }
  end
  
  def serialize_step_detail(step)
    {
      id: step.id,
      journey_id: step.journey_id,
      name: step.name,
      description: step.description,
      step_type: step.step_type,
      stage: step.stage,
      position: step.position,
      timing: step.timing,
      status: step.status,
      trigger_conditions: step.trigger_conditions,
      success_criteria: step.success_criteria,
      content: step.content,
      metadata: step.metadata,
      settings: step.settings,
      created_at: step.created_at,
      updated_at: step.updated_at,
      transitions_count: {
        outgoing: step.transitions_from.count,
        incoming: step.transitions_to.count
      }
    }
  end
  
  def serialize_transition(transition)
    {
      id: transition.id,
      from_step_id: transition.from_step_id,
      to_step_id: transition.to_step_id,
      from_step_name: transition.from_step.name,
      to_step_name: transition.to_step.name,
      condition_type: transition.condition_type,
      condition_data: transition.condition_data,
      weight: transition.weight,
      metadata: transition.metadata,
      created_at: transition.created_at
    }
  end
  
  def execute_step(step, execution_params)
    # Placeholder for step execution logic
    # This would integrate with the journey execution engine
    {
      step_id: step.id,
      execution_id: SecureRandom.uuid,
      status: 'executed',
      executed_at: Time.current,
      result: 'success',
      metadata: execution_params[:metadata] || {}
    }
  end
  
  def calculate_step_completion_rate(executions)
    return 0.0 if executions.empty?
    
    completed = executions.select { |e| e.status == 'completed' }.count
    (completed.to_f / executions.count * 100).round(2)
  end
  
  def calculate_average_duration(executions)
    durations = executions.filter_map do |e|
      next unless e.completed_at && e.started_at
      (e.completed_at - e.started_at).to_i
    end
    
    return 0 if durations.empty?
    (durations.sum.to_f / durations.count).round(2)
  end
  
  def calculate_step_success_rate(executions)
    return 0.0 if executions.empty?
    
    successful = executions.select { |e| %w[completed success].include?(e.status) }.count
    (successful.to_f / executions.count * 100).round(2)
  end
  
  def calculate_step_conversions(executions)
    # Placeholder for conversion tracking
    {
      total_conversions: 0,
      conversion_rate: 0.0,
      conversion_value: 0.0
    }
  end
  
  def calculate_step_engagement(executions)
    # Placeholder for engagement metrics
    {
      engagement_score: 0.0,
      interaction_count: 0,
      average_time_spent: 0.0
    }
  end
end