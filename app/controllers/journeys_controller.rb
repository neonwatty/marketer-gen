class JourneysController < ApplicationController
  include Authentication
  include ActivityTracker
  
  before_action :set_journey, only: [:show, :edit, :update, :destroy, :duplicate, :publish, :archive, :builder]
  before_action :ensure_user_can_access_journey, only: [:show, :edit, :update, :destroy, :duplicate, :publish, :archive, :builder]
  
  # GET /journeys
  def index
    @journeys = policy_scope(Journey)
    
    # Apply filters
    @journeys = @journeys.where(status: params[:status]) if params[:status].present?
    @journeys = @journeys.where(campaign_type: params[:campaign_type]) if params[:campaign_type].present?
    @journeys = @journeys.joins(:campaign).where(campaigns: { id: params[:campaign_id] }) if params[:campaign_id].present?
    
    # Apply search
    if params[:search].present?
      @journeys = @journeys.where("name LIKE ? OR description LIKE ?", 
                                  "%#{params[:search]}%", "%#{params[:search]}%")
    end
    
    # Apply sorting
    case params[:sort_by]
    when 'name'
      @journeys = @journeys.order(:name)
    when 'created_at'
      @journeys = @journeys.order(:created_at)
    when 'status'
      @journeys = @journeys.order(:status)
    else
      @journeys = @journeys.order(updated_at: :desc)
    end
    
    @journeys = @journeys.includes(:campaign, :journey_steps, :user)
                         .page(params[:page])
                         .per(params[:per_page] || 12)
    
    # Track activity
    log_custom_activity('viewed_journeys_list', { count: @journeys.total_count })
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_journeys_for_json(@journeys) }
    end
  end
  
  # GET /journeys/:id
  def show
    @journey_steps = @journey.journey_steps.includes(:transitions_from, :transitions_to).by_position
    @campaign = @journey.campaign
    @analytics_summary = @journey.analytics_summary(30)
    @performance_score = @journey.latest_performance_score
    
    # Track activity
    log_custom_activity('viewed_journey', { journey_id: @journey.id, journey_name: @journey.name })
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_journey_for_json(@journey) }
    end
  end
  
  # GET /journeys/new
  def new
    @journey = current_user.journeys.build
    @campaigns = current_user.campaigns.active
    @brands = current_user.brands
    
    # Set defaults from template if provided
    if params[:template_id].present?
      @template = JourneyTemplate.find(params[:template_id])
      @journey.name = @template.name
      @journey.description = @template.description
      @journey.campaign_type = @template.campaign_type
    end
    
    authorize @journey
    
    respond_to do |format|
      format.html
      format.json { render json: { journey: serialize_journey_for_json(@journey) } }
    end
  end
  
  # POST /journeys
  def create
    @journey = current_user.journeys.build(journey_params)
    authorize @journey
    
    respond_to do |format|
      if @journey.save
        # Track activity
        log_custom_activity('created_journey', { 
          journey_id: @journey.id, 
          journey_name: @journey.name,
          campaign_type: @journey.campaign_type
        })
        
        format.html { redirect_to @journey, notice: 'Journey was successfully created.' }
        format.json { render json: serialize_journey_for_json(@journey), status: :created }
      else
        @campaigns = current_user.campaigns.active
        @brands = current_user.brands
        
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @journey.errors.as_json }, status: :unprocessable_entity }
      end
    end
  end
  
  # GET /journeys/:id/edit
  def edit
    @campaigns = current_user.campaigns.active
    @brands = current_user.brands
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_journey_for_json(@journey) }
    end
  end
  
  # PATCH/PUT /journeys/:id
  def update
    respond_to do |format|
      if @journey.update(journey_params)
        # Track activity
        log_custom_activity('updated_journey', { 
          journey_id: @journey.id, 
          journey_name: @journey.name,
          changes: @journey.saved_changes.keys
        })
        
        format.html { redirect_to @journey, notice: 'Journey was successfully updated.' }
        format.json { render json: serialize_journey_for_json(@journey) }
      else
        @campaigns = current_user.campaigns.active
        @brands = current_user.brands
        
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @journey.errors.as_json }, status: :unprocessable_entity }
      end
    end
  end
  
  # DELETE /journeys/:id
  def destroy
    journey_name = @journey.name
    @journey.destroy!
    
    # Track activity
    log_custom_activity('deleted_journey', { 
      journey_name: journey_name,
      journey_id: params[:id]
    })
    
    respond_to do |format|
      format.html { redirect_to journeys_path, notice: 'Journey was successfully deleted.' }
      format.json { render json: { message: 'Journey was successfully deleted.' } }
    end
  end
  
  # POST /journeys/:id/duplicate
  def duplicate
    begin
      @new_journey = @journey.duplicate
      
      # Track activity
      log_custom_activity('duplicated_journey', { 
        original_journey_id: @journey.id,
        new_journey_id: @new_journey.id,
        journey_name: @new_journey.name
      })
      
      respond_to do |format|
        format.html { redirect_to @new_journey, notice: 'Journey was successfully duplicated.' }
        format.json { render json: serialize_journey_for_json(@new_journey), status: :created }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to @journey, alert: "Failed to duplicate journey: #{e.message}" }
        format.json { render json: { error: "Failed to duplicate journey: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end
  
  # POST /journeys/:id/publish
  def publish
    respond_to do |format|
      if @journey.publish!
        # Track activity
        log_custom_activity('published_journey', { 
          journey_id: @journey.id,
          journey_name: @journey.name
        })
        
        format.html { redirect_to @journey, notice: 'Journey was successfully published.' }
        format.json { render json: serialize_journey_for_json(@journey) }
      else
        format.html { redirect_to @journey, alert: 'Failed to publish journey.' }
        format.json { render json: { errors: @journey.errors.as_json }, status: :unprocessable_entity }
      end
    end
  end
  
  # POST /journeys/:id/archive
  def archive
    respond_to do |format|
      if @journey.archive!
        # Track activity
        log_custom_activity('archived_journey', { 
          journey_id: @journey.id,
          journey_name: @journey.name
        })
        
        format.html { redirect_to @journey, notice: 'Journey was successfully archived.' }
        format.json { render json: serialize_journey_for_json(@journey) }
      else
        format.html { redirect_to @journey, alert: 'Failed to archive journey.' }
        format.json { render json: { errors: @journey.errors.as_json }, status: :unprocessable_entity }
      end
    end
  end
  
  # GET /journeys/:id/builder
  def builder
    @journey_steps = @journey.journey_steps.includes(:transitions_from, :transitions_to).by_position
    
    # Track activity
    log_custom_activity('opened_journey_builder', { 
      journey_id: @journey.id,
      journey_name: @journey.name
    })
    
    respond_to do |format|
      format.html
      format.json { render json: serialize_journey_for_builder(@journey) }
    end
  end
  
  private
  
  def set_journey
    @journey = Journey.find(params[:id])
  end
  
  def ensure_user_can_access_journey
    authorize @journey
  end
  
  def journey_params
    permitted_params = params.require(:journey).permit(
      :name, :description, :campaign_type, :target_audience, :status,
      :campaign_id, :brand_id, :goals, metadata: {}, settings: {}
    )
    
    # Handle goals conversion from string to array
    if permitted_params[:goals].is_a?(String)
      permitted_params[:goals] = permitted_params[:goals].split("\n").map(&:strip).reject(&:blank?)
    end
    
    permitted_params
  end
  
  def serialize_journeys_for_json(journeys)
    {
      journeys: journeys.map { |journey| serialize_journey_summary(journey) },
      pagination: {
        current_page: journeys.current_page,
        total_pages: journeys.total_pages,
        total_count: journeys.total_count,
        per_page: journeys.limit_value
      }
    }
  end
  
  def serialize_journey_for_json(journey)
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
      brand_id: journey.brand_id,
      campaign: journey.campaign ? serialize_campaign_summary(journey.campaign) : nil,
      brand: journey.brand ? serialize_brand_summary(journey.brand) : nil,
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
  
  def serialize_journey_summary(journey)
    {
      id: journey.id,
      name: journey.name,
      description: journey.description,
      status: journey.status,
      campaign_type: journey.campaign_type,
      campaign_id: journey.campaign_id,
      campaign_name: journey.campaign&.name,
      brand_id: journey.brand_id,
      brand_name: journey.brand&.name,
      step_count: journey.total_steps,
      created_at: journey.created_at,
      updated_at: journey.updated_at,
      published_at: journey.published_at,
      performance_score: journey.latest_performance_score
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
  
  def serialize_brand_summary(brand)
    {
      id: brand.id,
      name: brand.name,
      industry: brand.industry,
      status: brand.status
    }
  end
  
  def serialize_journey_for_builder(journey)
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
      brand_id: journey.brand_id,
      steps: serialize_journey_steps_for_builder(journey.journey_steps.by_position),
      created_at: journey.created_at,
      updated_at: journey.updated_at
    }
  end
  
  def serialize_journey_steps_for_builder(steps)
    steps.map do |step|
      {
        id: step.id,
        name: step.name,
        description: step.description,
        stage: step.stage,
        position: {
          x: step.metadata&.dig('canvas', 'x') || (step.position * 300 + 100),
          y: step.metadata&.dig('canvas', 'y') || 100
        },
        step_position: step.position,
        content_type: step.content_type,
        channel: step.channel,
        duration_days: step.duration_days,
        config: step.config || {},
        conditions: step.conditions || {},
        metadata: step.metadata || {},
        is_entry_point: step.is_entry_point,
        is_exit_point: step.is_exit_point,
        transitions_from: step.transitions_from.map { |t| { 
          id: t.id, 
          to_step_id: t.to_step_id, 
          conditions: t.conditions || {},
          transition_type: t.transition_type 
        }},
        transitions_to: step.transitions_to.map { |t| { 
          id: t.id, 
          from_step_id: t.from_step_id, 
          conditions: t.conditions || {},
          transition_type: t.transition_type 
        }}
      }
    end
  end
end