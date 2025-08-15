class JourneysController < ApplicationController
  before_action :require_authentication
  before_action :set_journey, only: [:show, :edit, :update, :destroy, :reorder_steps, :suggestions, :duplicate, :archive]

  def index
    authorize Journey
    @journeys = policy_scope(Journey).includes(:journey_steps)
                                   .order(created_at: :desc)
    
    # Apply search if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @journeys = @journeys.where("name LIKE ? OR description LIKE ?", search_term, search_term)
    end
    
    # Apply filters if present
    @journeys = @journeys.by_campaign_type(params[:campaign_type]) if params[:campaign_type].present?
    @journeys = @journeys.by_template_type(params[:template_type]) if params[:template_type].present?
    @journeys = @journeys.where(status: params[:status]) if params[:status].present?
    
    # Analytics data
    @analytics = {
      total_journeys: @journeys.count,
      active_journeys: @journeys.where(status: 'active').count,
      completed_journeys: @journeys.where(status: 'completed').count,
      average_completion_rate: calculate_average_completion_rate(@journeys)
    }
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

  def duplicate
    authorize @journey, :show?
    
    # Create a duplicate journey
    new_journey = @journey.dup
    new_journey.name = "#{@journey.name} (Copy)"
    new_journey.status = 'draft'
    new_journey.user = Current.user
    
    if new_journey.save
      # Duplicate journey steps
      @journey.journey_steps.each do |step|
        new_step = step.dup
        new_step.journey = new_journey
        new_step.status = 'draft'
        new_step.save!
      end
      
      redirect_to edit_journey_path(new_journey), notice: 'Journey duplicated successfully. You can now customize it.'
    else
      redirect_to @journey, alert: 'Failed to duplicate journey.'
    end
  end

  def archive
    authorize @journey, :update?
    
    if @journey.can_be_archived?
      @journey.update(status: 'archived')
      redirect_to journeys_path, notice: 'Journey archived successfully.'
    else
      redirect_to @journey, alert: 'Journey cannot be archived in its current state.'
    end
  end

  def compare
    authorize Journey
    @journey_ids = params[:journey_ids]&.reject(&:blank?)
    
    if @journey_ids.blank?
      redirect_to journeys_path, alert: 'Please select journeys to compare.'
      return
    end
    
    if @journey_ids.length < 2
      redirect_to journeys_path, alert: 'Please select at least 2 journeys to compare.'
      return
    end
    
    if @journey_ids.length > 4
      redirect_to journeys_path, alert: 'Please select no more than 4 journeys to compare.'
      return
    end
    
    @journeys = policy_scope(Journey).includes(:journey_steps).where(id: @journey_ids)
    
    @comparison_data = @journeys.map do |journey|
      {
        journey: journey,
        analytics: journey.analytics_summary,
        steps_by_type: journey.journey_steps.group(:step_type).count,
        steps_by_channel: journey.journey_steps.group(:channel).count,
        steps_by_status: journey.journey_steps.group(:status).count
      }
    end
  end

  private

  def set_journey
    @journey = policy_scope(Journey).find(params[:id])
  end

  def journey_params
    params.require(:journey).permit(:name, :description, :campaign_type, :status, :template_type, stages: [], metadata: {})
  end

  def calculate_average_completion_rate(journeys)
    return 0 if journeys.empty?
    
    completion_rates = journeys.map(&:completion_rate)
    completion_rates.sum / completion_rates.length
  end
end