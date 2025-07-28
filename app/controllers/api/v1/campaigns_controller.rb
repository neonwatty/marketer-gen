class Api::V1::CampaignsController < Api::V1::BaseController
  before_action :set_campaign, only: [:show, :update, :destroy, :activate, :pause, :analytics]
  
  # GET /api/v1/campaigns
  def index
    campaigns = current_user.campaigns.includes(:persona, :journeys)
    
    # Apply filters
    campaigns = campaigns.where(status: params[:status]) if params[:status].present?
    campaigns = campaigns.where(campaign_type: params[:campaign_type]) if params[:campaign_type].present?
    campaigns = campaigns.where(industry: params[:industry]) if params[:industry].present?
    campaigns = campaigns.where(persona_id: params[:persona_id]) if params[:persona_id].present?
    
    # Apply search
    if params[:search].present?
      campaigns = campaigns.where(
        'name ILIKE ? OR description ILIKE ?',
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end
    
    # Apply sorting
    case params[:sort_by]
    when 'name'
      campaigns = campaigns.order(:name)
    when 'status'
      campaigns = campaigns.order(:status, :name)
    when 'created_at'
      campaigns = campaigns.order(:created_at)
    when 'updated_at'
      campaigns = campaigns.order(:updated_at)
    else
      campaigns = campaigns.order(updated_at: :desc)
    end
    
    paginate_and_render(campaigns, serializer: method(:serialize_campaign_summary))
  end
  
  # GET /api/v1/campaigns/:id
  def show
    render_success(data: serialize_campaign_detail(@campaign))
  end
  
  # POST /api/v1/campaigns
  def create
    campaign = current_user.campaigns.build(campaign_params)
    
    if campaign.save
      render_success(
        data: serialize_campaign_detail(campaign),
        message: 'Campaign created successfully',
        status: :created
      )
    else
      render_error(
        message: 'Failed to create campaign',
        errors: campaign.errors.as_json
      )
    end
  end
  
  # PUT /api/v1/campaigns/:id
  def update
    if @campaign.update(campaign_params)
      render_success(
        data: serialize_campaign_detail(@campaign),
        message: 'Campaign updated successfully'
      )
    else
      render_error(
        message: 'Failed to update campaign',
        errors: @campaign.errors.as_json
      )
    end
  end
  
  # DELETE /api/v1/campaigns/:id
  def destroy
    @campaign.destroy!
    render_success(message: 'Campaign deleted successfully')
  end
  
  # POST /api/v1/campaigns/:id/activate
  def activate
    if @campaign.activate!
      render_success(
        data: serialize_campaign_detail(@campaign),
        message: 'Campaign activated successfully'
      )
    else
      render_error(
        message: 'Failed to activate campaign',
        errors: @campaign.errors.as_json
      )
    end
  end
  
  # POST /api/v1/campaigns/:id/pause
  def pause
    if @campaign.pause!
      render_success(
        data: serialize_campaign_detail(@campaign),
        message: 'Campaign paused successfully'
      )
    else
      render_error(
        message: 'Failed to pause campaign',
        errors: @campaign.errors.as_json
      )
    end
  end
  
  # GET /api/v1/campaigns/:id/analytics
  def analytics
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    
    analytics_service = CampaignAnalyticsService.new(@campaign)
    analytics_data = analytics_service.generate_report(days)
    
    render_success(data: analytics_data)
  end
  
  # GET /api/v1/campaigns/:id/journeys
  def journeys
    journeys = @campaign.journeys.includes(:journey_steps, :journey_analytics)
    
    # Apply filters
    journeys = journeys.where(status: params[:status]) if params[:status].present?
    
    # Apply sorting
    case params[:sort_by]
    when 'name'
      journeys = journeys.order(:name)
    when 'performance'
      # Sort by latest performance score
      journeys = journeys.joins(:journey_analytics)
        .group('journeys.id')
        .order('AVG(journey_analytics.conversion_rate) DESC')
    else
      journeys = journeys.order(created_at: :desc)
    end
    
    paginate_and_render(journeys, serializer: method(:serialize_journey_for_campaign))
  end
  
  # POST /api/v1/campaigns/:id/journeys
  def add_journey
    journey_params = params.require(:journey).permit(:id, :name, :description)
    
    if journey_params[:id].present?
      # Associate existing journey
      journey = current_user.journeys.find(journey_params[:id])
      journey.update!(campaign: @campaign)
    else
      # Create new journey for campaign
      journey = @campaign.journeys.build(
        journey_params.merge(user: current_user)
      )
      journey.save!
    end
    
    render_success(
      data: serialize_journey_for_campaign(journey),
      message: 'Journey added to campaign successfully',
      status: :created
    )
  end
  
  # DELETE /api/v1/campaigns/:id/journeys/:journey_id
  def remove_journey
    journey = @campaign.journeys.find(params[:journey_id])
    journey.update!(campaign: nil)
    
    render_success(message: 'Journey removed from campaign successfully')
  end
  
  # GET /api/v1/campaigns/industries
  def industries
    industries = Campaign.where(user: current_user).distinct.pluck(:industry).compact.sort
    render_success(data: industries)
  end
  
  # GET /api/v1/campaigns/types
  def types
    types = Campaign::CAMPAIGN_TYPES
    render_success(data: types)
  end
  
  private
  
  def set_campaign
    @campaign = current_user.campaigns.find(params[:id])
  end
  
  def campaign_params
    params.require(:campaign).permit(
      :name, :description, :campaign_type, :industry, :status,
      :start_date, :end_date, :budget, :persona_id,
      goals: [], target_metrics: {}, settings: {}
    )
  end
  
  def serialize_campaign_summary(campaign)
    {
      id: campaign.id,
      name: campaign.name,
      description: campaign.description,
      campaign_type: campaign.campaign_type,
      industry: campaign.industry,
      status: campaign.status,
      persona_id: campaign.persona_id,
      persona_name: campaign.persona&.name,
      journey_count: campaign.journeys.count,
      start_date: campaign.start_date,
      end_date: campaign.end_date,
      budget: campaign.budget,
      created_at: campaign.created_at,
      updated_at: campaign.updated_at
    }
  end
  
  def serialize_campaign_detail(campaign)
    {
      id: campaign.id,
      name: campaign.name,
      description: campaign.description,
      campaign_type: campaign.campaign_type,
      industry: campaign.industry,
      status: campaign.status,
      start_date: campaign.start_date,
      end_date: campaign.end_date,
      budget: campaign.budget,
      goals: campaign.goals,
      target_metrics: campaign.target_metrics,
      settings: campaign.settings,
      persona: campaign.persona ? serialize_persona_for_campaign(campaign.persona) : nil,
      journey_count: campaign.journeys.count,
      created_at: campaign.created_at,
      updated_at: campaign.updated_at
    }
  end
  
  def serialize_persona_for_campaign(persona)
    {
      id: persona.id,
      name: persona.name,
      age_range: persona.age_range,
      location: persona.location,
      demographic_data: persona.demographic_data,
      psychographic_data: persona.psychographic_data
    }
  end
  
  def serialize_journey_for_campaign(journey)
    {
      id: journey.id,
      name: journey.name,
      description: journey.description,
      status: journey.status,
      step_count: journey.total_steps,
      performance_score: journey.latest_performance_score,
      created_at: journey.created_at,
      updated_at: journey.updated_at
    }
  end
end