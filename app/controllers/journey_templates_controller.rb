class JourneyTemplatesController < ApplicationController
  before_action :set_journey_template, only: [:show, :preview, :apply_to_campaign, :duplicate, :publish, :unpublish]

  # GET /journey_templates
  def index
    @templates = filter_templates.page(params[:page]).per(12)
    @categories = JourneyTemplate.distinct.pluck(:category).compact.sort
    @template_types = JourneyTemplate.distinct.pluck(:template_type).sort
    
    respond_to do |format|
      format.html
      format.json { render json: templates_json_response }
    end
  end

  # GET /journey_templates/1
  def show
    @template_stages = @template.template_data['stages'] || []
    @usage_stats = calculate_usage_stats(@template)
  end

  # GET /journey_templates/1/preview  
  def preview
    render json: {
      template: template_preview_data(@template),
      stages: @template.template_data['stages'] || [],
      variables: @template.variables || [],
      metadata: template_metadata(@template)
    }
  end

  # POST /journey_templates/1/apply_to_campaign
  def apply_to_campaign
    @campaign = Campaign.find(params[:campaign_id])
    
    begin
      @journey = @template.create_journey_from_template(@campaign, journey_params)
      
      if @journey&.persisted?
        render json: {
          success: true,
          journey: journey_json(@journey),
          message: "Template applied successfully to #{@campaign.name}"
        }
      else
        render json: {
          success: false,
          errors: @journey&.errors&.full_messages || ['Failed to create journey from template'],
          message: 'Failed to apply template'
        }, status: :unprocessable_entity
      end
    rescue => e
      render json: {
        success: false,
        message: 'Error applying template to campaign',
        error: e.message
      }, status: :internal_server_error
    end
  end

  # POST /journey_templates/1/duplicate
  def duplicate
    begin
      new_template = @template.create_new_version(duplicate_params)
      
      render json: {
        success: true,
        template: template_preview_data(new_template),
        message: "Template duplicated as version #{new_template.version}"
      }
    rescue => e
      render json: {
        success: false,
        message: 'Failed to duplicate template',
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # PATCH /journey_templates/1/publish
  def publish
    if @template.publish!
      render json: {
        success: true,
        message: 'Template published successfully'
      }
    else
      render json: {
        success: false,
        errors: @template.errors.full_messages,
        message: 'Failed to publish template'
      }, status: :unprocessable_entity
    end
  end

  # PATCH /journey_templates/1/unpublish
  def unpublish
    if @template.unpublish!
      render json: {
        success: true,
        message: 'Template unpublished successfully'
      }
    else
      render json: {
        success: false,
        errors: @template.errors.full_messages,
        message: 'Failed to unpublish template'
      }, status: :unprocessable_entity
    end
  end

  # GET /journey_templates/categories
  def categories
    categories_with_counts = JourneyTemplate.active.published
      .group(:category)
      .count
      .map { |category, count| { name: category || 'General', count: count } }
    
    render json: { categories: categories_with_counts }
  end

  # GET /journey_templates/search
  def search
    query = params[:q]&.strip
    return render json: { templates: [] } if query.blank?

    templates = JourneyTemplate.active.published
      .where("name ILIKE ? OR description ILIKE ? OR tags ILIKE ?", 
             "%#{query}%", "%#{query}%", "%#{query}%")
      .limit(20)
    
    render json: {
      templates: templates.map { |t| template_search_result(t) },
      total: templates.count
    }
  end

  private

  def set_journey_template
    @template = JourneyTemplate.find(params[:id])
  end

  def filter_templates
    scope = JourneyTemplate.active.published.recent

    # Filter by category
    if params[:category].present? && params[:category] != 'all'
      scope = scope.by_category(params[:category])
    end

    # Filter by template type
    if params[:template_type].present? && params[:template_type] != 'all'
      scope = scope.by_template_type(params[:template_type])
    end

    # Search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      scope = scope.where(
        "name ILIKE ? OR description ILIKE ? OR tags ILIKE ?",
        search_term, search_term, search_term
      )
    end

    # Sort options
    case params[:sort]
    when 'popular'
      scope = scope.popular
    when 'name'
      scope = scope.order(:name)
    else
      scope = scope.recent
    end

    scope
  end

  def journey_params
    params.permit(:name, :purpose, :goals, :timing, :audience, variables: {})
  end

  def duplicate_params
    params.permit(:name, :description, :category, :tags)
  end

  def templates_json_response
    {
      templates: @templates.map { |t| template_preview_data(t) },
      pagination: {
        current_page: @templates.current_page,
        total_pages: @templates.total_pages,
        total_count: @templates.total_count,
        per_page: @templates.limit_value
      },
      filters: {
        categories: @categories,
        template_types: @template_types
      }
    }
  end

  def template_preview_data(template)
    {
      id: template.id,
      name: template.name,
      description: template.description,
      template_type: template.template_type,
      template_type_humanized: template.template_type_humanized,
      category: template.category,
      category_humanized: template.category_humanized,
      version: template.version,
      usage_count: template.usage_count,
      stage_count: template.stage_count,
      estimated_duration_days: template.estimated_duration_days,
      published: template.published?,
      active: template.is_active,
      tags: template.tags_array,
      author: template.author,
      created_at: template.created_at,
      published_at: template.published_at,
      adoption_rate: template.adoption_rate
    }
  end

  def template_metadata(template)
    {
      summary: template.summary_info,
      required_variables: template.required_variables,
      optional_variables: template.optional_variables,
      latest_version: template.latest_version?,
      previous_version_id: template.parent_template_id,
      next_version_id: template.next_version&.id
    }
  end

  def template_search_result(template)
    {
      id: template.id,
      name: template.name,
      description: template.description&.truncate(100),
      category: template.category_humanized,
      template_type: template.template_type_humanized,
      stage_count: template.stage_count,
      duration: template.estimated_duration_days
    }
  end

  def journey_json(journey)
    {
      id: journey.id,
      name: journey.name,
      template_type: journey.template_type,
      stage_count: journey.journey_stages.count,
      created_at: journey.created_at
    }
  end

  def calculate_usage_stats(template)
    {
      total_usage: template.usage_count,
      recent_usage: Journey.where(template_type: template.template_type)
                          .where('created_at > ?', 30.days.ago).count,
      adoption_rate: template.adoption_rate,
      success_rate: calculate_template_success_rate(template)
    }
  end

  def calculate_template_success_rate(template)
    journeys = Journey.where(template_type: template.template_type)
    return 0 if journeys.count == 0
    
    # Define success as journeys with completed stages
    successful = journeys.joins(:journey_stages)
                        .where(journey_stages: { status: 'completed' })
                        .distinct.count
    
    ((successful.to_f / journeys.count) * 100).round(2)
  end
end