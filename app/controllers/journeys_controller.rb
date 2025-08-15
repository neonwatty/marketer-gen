class JourneysController < ApplicationController
  before_action :require_authentication
  before_action :set_journey, only: [:show, :edit, :update, :destroy, :reorder_steps, :suggestions]

  def index
    authorize Journey
    @journeys = policy_scope(Journey).includes(:journey_steps)
                                   .order(created_at: :desc)
    
    # Apply filters if present
    @journeys = @journeys.by_campaign_type(params[:campaign_type]) if params[:campaign_type].present?
    @journeys = @journeys.by_template_type(params[:template_type]) if params[:template_type].present?
    @journeys = @journeys.where(status: params[:status]) if params[:status].present?
  end

  def show
    authorize @journey
    @journey_steps = @journey.ordered_steps
  end

  def new
    @journey = Current.user.journeys.build
    authorize @journey
    @journey.template_type = params[:template_type] if params[:template_type].present?
  end

  def create
    @journey = Current.user.journeys.build(journey_params)
    authorize @journey
    
    if @journey.save
      redirect_to @journey, notice: 'Journey was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @journey
  end

  def update
    authorize @journey
    if @journey.update(journey_params)
      redirect_to @journey, notice: 'Journey was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @journey
    @journey.destroy
    redirect_to journeys_url, notice: 'Journey was successfully deleted.'
  end

  def reorder_steps
    authorize @journey, :reorder_steps?
    step_ids = params[:step_ids]
    
    # Use a transaction to handle the reordering safely
    ActiveRecord::Base.transaction do
      # First, set all steps to negative values to avoid conflicts
      step_ids.each_with_index do |step_id, index|
        step = @journey.journey_steps.find(step_id)
        step.update_column(:sequence_order, -(index + 1))
      end
      
      # Then set the correct positive values
      step_ids.each_with_index do |step_id, index|
        step = @journey.journey_steps.find(step_id)
        step.update_column(:sequence_order, index)
      end
    end
    
    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def suggestions
    authorize @journey, :show?
    
    # Get existing steps for filtering
    existing_steps = @journey.journey_steps.map { |step| { step_type: step.step_type } }
    
    # Get current stage from params or use first stage (handle parameter pollution)
    stage_param = params[:stage].is_a?(Array) ? params[:stage].first : params[:stage]
    current_stage = stage_param || @journey.stages&.first
    
    # Initialize suggestion service
    suggestion_service = JourneySuggestionService.new(
      campaign_type: @journey.campaign_type,
      template_type: @journey.template_type,
      current_stage: current_stage,
      existing_steps: existing_steps
    )
    
    # Get suggestions with safe limit parameter handling
    limit = params[:limit].is_a?(Array) ? params[:limit].first : params[:limit]
    limit = limit&.to_i || 5
    suggestions = suggestion_service.suggest_steps(limit: limit)
    
    # Enhance suggestions with additional details
    enhanced_suggestions = suggestions.map do |suggestion|
      channels = suggestion_service.suggest_channels_for_step(suggestion[:step_type])
      content = suggestion_service.suggest_content_for_step(suggestion[:step_type], current_stage)
      
      suggestion.merge(
        suggested_channels: channels,
        content_suggestions: content
      )
    end
    
    render json: {
      suggestions: enhanced_suggestions,
      current_stage: current_stage,
      available_stages: @journey.stages,
      campaign_type: @journey.campaign_type
    }
  end

  private

  def set_journey
    @journey = policy_scope(Journey).find(params[:id])
  end

  def journey_params
    params.require(:journey).permit(:name, :description, :campaign_type, :status, :template_type, stages: [], metadata: {})
  end
end