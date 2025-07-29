class Api::V1::JourneysController < Api::V1::BaseController
  before_action :set_journey, only: [:show, :update, :destroy, :duplicate, :publish, :archive, :analytics, :execution_status]
  
  # GET /api/v1/journeys
  def index
    journeys = current_user.journeys.includes(:campaign, :persona, :journey_steps)
    
    # Apply filters
    journeys = journeys.where(status: params[:status]) if params[:status].present?
    journeys = journeys.where(campaign_type: params[:campaign_type]) if params[:campaign_type].present?
    journeys = journeys.joins(:campaign).where(campaigns: { id: params[:campaign_id] }) if params[:campaign_id].present?
    
    # Apply sorting
    case params[:sort_by]
    when 'name'
      journeys = journeys.order(:name)
    when 'created_at'
      journeys = journeys.order(:created_at)
    when 'updated_at'
      journeys = journeys.order(:updated_at)
    when 'status'
      journeys = journeys.order(:status)
    else
      journeys = journeys.order(updated_at: :desc)
    end
    
    paginate_and_render(journeys, serializer: method(:serialize_journey_summary))
  end
  
  # GET /api/v1/journeys/:id
  def show
    render_success(data: serialize_journey_detail(@journey))
  end
  
  # POST /api/v1/journeys
  def create
    journey = current_user.journeys.build(journey_params)
    
    if journey.save
      render_success(
        data: serialize_journey_detail(journey),
        message: 'Journey created successfully',
        status: :created
      )
    else
      render_error(
        message: 'Failed to create journey',
        errors: journey.errors.as_json
      )
    end
  end
  
  # PUT /api/v1/journeys/:id
  def update
    if @journey.update(journey_params)
      render_success(
        data: serialize_journey_detail(@journey),
        message: 'Journey updated successfully'
      )
    else
      render_error(
        message: 'Failed to update journey',
        errors: @journey.errors.as_json
      )
    end
  end
  
  # DELETE /api/v1/journeys/:id
  def destroy
    @journey.destroy!
    render_success(message: 'Journey deleted successfully')
  end
  
  # POST /api/v1/journeys/:id/duplicate
  def duplicate
    begin
      new_journey = @journey.duplicate
      render_success(
        data: serialize_journey_detail(new_journey),
        message: 'Journey duplicated successfully',
        status: :created
      )
    rescue => e
      render_error(message: "Failed to duplicate journey: #{e.message}")
    end
  end
  
  # POST /api/v1/journeys/:id/publish
  def publish
    if @journey.publish!
      render_success(
        data: serialize_journey_detail(@journey),
        message: 'Journey published successfully'
      )
    else
      render_error(
        message: 'Failed to publish journey',
        errors: @journey.errors.as_json
      )
    end
  end
  
  # POST /api/v1/journeys/:id/archive
  def archive
    if @journey.archive!
      render_success(
        data: serialize_journey_detail(@journey),
        message: 'Journey archived successfully'
      )
    else
      render_error(
        message: 'Failed to archive journey',
        errors: @journey.errors.as_json
      )
    end
  end
  
  # GET /api/v1/journeys/:id/analytics
  def analytics
    days = [params[:days].to_i, 1].max
    days = [days, 365].min # Cap at 1 year
    
    analytics_data = {
      summary: @journey.analytics_summary(days),
      performance_score: @journey.latest_performance_score,
      funnel_performance: @journey.funnel_performance('default', days),
      trends: @journey.performance_trends(7),
      ab_test_status: @journey.ab_test_status
    }
    
    render_success(data: analytics_data)
  end
  
  # GET /api/v1/journeys/:id/execution_status
  def execution_status
    executions = @journey.journey_executions
      .includes(:step_executions)
      .order(created_at: :desc)
      .limit(params[:limit]&.to_i || 10)
    
    execution_data = executions.map do |execution|
      {
        id: execution.id,
        status: execution.status,
        started_at: execution.started_at,
        completed_at: execution.completed_at,
        current_step_id: execution.current_step_id,
        step_count: execution.step_executions.count,
        completion_percentage: execution.completion_percentage,
        metadata: execution.metadata
      }
    end
    
    render_success(data: execution_data)
  end
  
  private
  
  def set_journey
    @journey = current_user.journeys.find(params[:id])
  end
  
  def journey_params
    params.require(:journey).permit(
      :name, :description, :campaign_type, :target_audience, :status,
      :campaign_id, goals: [], metadata: {}, settings: {}
    )
  end
  
  def serialize_journey_summary(journey)
    {
      id: journey.id,
      name: journey.name,
      description: journey.description,
      status: journey.status,
      campaign_type: journey.campaign_type,
      campaign_id: journey.campaign_id,
      campaign_name: journey.campaign&.name,
      persona_name: journey.persona&.name,
      step_count: journey.total_steps,
      created_at: journey.created_at,
      updated_at: journey.updated_at,
      published_at: journey.published_at,
      performance_score: journey.latest_performance_score
    }
  end
  
  def serialize_journey_detail(journey)
    {
      id: journey.id,
      name: journey.name,
      description: journey.description,
      status: journey.status,
      campaign_type: journey.campaign_type,
      target_audience: journey.target_audience,
      goals: journey.goals,
      metadata: journey.metadata,
      settings: journey.settings,
      campaign_id: journey.campaign_id,
      campaign: journey.campaign ? serialize_campaign_summary(journey.campaign) : nil,
      persona: journey.persona ? serialize_persona_summary(journey.persona) : nil,
      step_count: journey.total_steps,
      steps_by_stage: journey.steps_by_stage,
      created_at: journey.created_at,
      updated_at: journey.updated_at,
      published_at: journey.published_at,
      archived_at: journey.archived_at,
      performance_score: journey.latest_performance_score,
      ab_test_status: journey.ab_test_status
    }
  end
  
  def serialize_campaign_summary(campaign)
    {
      id: campaign.id,
      name: campaign.name,
      campaign_type: campaign.campaign_type,
      status: campaign.status
    }
  end
  
  def serialize_persona_summary(persona)
    {
      id: persona.id,
      name: persona.name,
      demographic_data: persona.demographic_data,
      psychographic_data: persona.psychographic_data
    }
  end
end