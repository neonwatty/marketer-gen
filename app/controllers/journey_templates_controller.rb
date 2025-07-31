class JourneyTemplatesController < ApplicationController
  include Authentication
  include ActivityTracker
  
  before_action :set_journey_template, only: [:show, :edit, :update, :destroy, :clone, :use_template, :builder, :builder_react]
  before_action :ensure_user_can_access_template, only: [:show, :edit, :update, :destroy, :clone, :use_template, :builder, :builder_react]
  
  def index
    @templates = policy_scope(JourneyTemplate).active.includes(:journeys)
    
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
    
    # Track activity
    track_activity('viewed_journey_templates', { count: @templates.count })
  end

  def show
    @preview_steps = @template.preview_steps
    @stages_covered = @template.stages_covered
    @channels_used = @template.channels_used
    @content_types = @template.content_types_included
    
    # Track activity
    track_activity('viewed_journey_template', { 
      template_id: @template.id,
      template_name: @template.name
    })
  end

  def new
    @template = JourneyTemplate.new
    authorize @template
  end

  def create
    @template = JourneyTemplate.new(template_params)
    authorize @template
    
    if @template.save
      # Track activity
      track_activity('created_journey_template', { 
        template_id: @template.id,
        template_name: @template.name,
        category: @template.category
      })
      
      respond_to do |format|
        format.html { redirect_to @template, notice: 'Journey template was successfully created.' }
        format.json { render json: @template, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @template.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @template.update(template_params)
      # Track activity
      track_activity('updated_journey_template', { 
        template_id: @template.id,
        template_name: @template.name,
        changes: @template.saved_changes.keys
      })
      
      respond_to do |format|
        format.html { redirect_to @template, notice: 'Journey template was successfully updated.' }
        format.json { render json: @template }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @template.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    template_name = @template.name
    @template.update!(is_active: false)
    
    # Track activity
    track_activity('deactivated_journey_template', { 
      template_id: @template.id,
      template_name: template_name
    })
    
    redirect_to journey_templates_path, notice: 'Journey template was deactivated.'
  end
  
  def clone
    new_template = @template.dup
    new_template.name = "#{@template.name} (Copy)"
    new_template.usage_count = 0
    new_template.is_active = true
    
    if new_template.save
      # Track activity
      track_activity('cloned_journey_template', { 
        original_template_id: @template.id,
        new_template_id: new_template.id,
        template_name: new_template.name
      })
      
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
      # Track activity
      track_activity('used_journey_template', { 
        template_id: @template.id,
        template_name: @template.name,
        journey_id: journey.id,
        journey_name: journey.name
      })
      
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
  
  def builder_react
    # React-based visual journey builder interface
    @template ||= JourneyTemplate.new
    
    # Prepare data for React component
    @journey_data = {
      id: @template.id,
      name: @template.name || 'New Journey',
      description: @template.description || '',
      steps: @template.steps_data || [],
      connections: @template.connections_data || [],
      status: @template.published? ? 'published' : 'draft'
    }
  end

  private

  def set_journey_template
    if params[:id] == 'new'
      @template = JourneyTemplate.new
    else
      @template = JourneyTemplate.find(params[:id])
    end
  end
  
  def ensure_user_can_access_template
    authorize @template
  end

  def template_params
    params.require(:journey_template).permit(
      :name, :description, :category, :campaign_type, :difficulty_level,
      :estimated_duration_days, :is_active, :template_data, :status,
      steps_data: [], connections_data: []
    )
  end
  
  def journey_params_for_template
    params.permit(:name, :description, :target_audience, :goals, :brand_id)
  end
end
