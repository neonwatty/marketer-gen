class JourneyTemplatesController < ApplicationController
  before_action :require_authentication
  before_action :set_journey_template, only: [:show, :edit, :update, :destroy, :clone, :use_template, :builder]
  
  def index
    @templates = JourneyTemplate.active.includes(:journeys)
    
    # Filter by category if specified
    @templates = @templates.by_category(params[:category]) if params[:category].present?
    
    # Filter by campaign type if specified  
    @templates = @templates.by_campaign_type(params[:campaign_type]) if params[:campaign_type].present?
    
    # Search by name or description
    if params[:search].present?
      @templates = @templates.where(
        "name ILIKE ? OR description ILIKE ?", 
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end
    
    # Sort templates
    case params[:sort]
    when 'popular'
      @templates = @templates.popular
    when 'recent'
      @templates = @templates.recent
    else
      @templates = @templates.order(:name)
    end
    
    @categories = JourneyTemplate::CATEGORIES
    @campaign_types = Journey::CAMPAIGN_TYPES
  end

  def show
    @preview_steps = @template.preview_steps
    @stages_covered = @template.stages_covered
    @channels_used = @template.channels_used
    @content_types = @template.content_types_included
  end

  def new
    @template = JourneyTemplate.new
  end

  def create
    @template = JourneyTemplate.new(template_params)
    
    if @template.save
      redirect_to @template, notice: 'Journey template was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      redirect_to @template, notice: 'Journey template was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template.update!(is_active: false)
    redirect_to journey_templates_path, notice: 'Journey template was deactivated.'
  end
  
  def clone
    new_template = @template.dup
    new_template.name = "#{@template.name} (Copy)"
    new_template.usage_count = 0
    new_template.is_active = true
    
    if new_template.save
      redirect_to edit_journey_template_path(new_template), 
                  notice: 'Template cloned successfully. You can now customize it.'
    else
      redirect_to @template, alert: 'Failed to clone template.'
    end
  end
  
  def use_template
    journey = @template.create_journey_for_user(
      current_user,
      journey_params_for_template
    )
    
    if journey.persisted?
      redirect_to journey_path(journey), 
                  notice: 'Journey created from template successfully!'
    else
      redirect_to @template, 
                  alert: "Failed to create journey: #{journey.errors.full_messages.join(', ')}"
    end
  end
  
  def builder
    # Visual journey builder interface
    @template ||= JourneyTemplate.new
    @existing_steps = @template.template_data&.dig('steps') || []
    @stages = ['awareness', 'consideration', 'conversion', 'retention']
    @step_types = JourneyStep::STEP_TYPES
  end

  private

  def set_journey_template
    if params[:id] == 'new'
      @template = JourneyTemplate.new
    else
      @template = JourneyTemplate.find(params[:id])
    end
  end

  def template_params
    params.require(:journey_template).permit(
      :name, :description, :category, :campaign_type, :difficulty_level,
      :estimated_duration_days, :is_active, :template_data
    )
  end
  
  def journey_params_for_template
    params.permit(:name, :description, :target_audience, :goals, :brand_id)
  end
end
