class Api::V1::JourneyTemplatesController < Api::V1::BaseController
  before_action :set_template, only: [:show, :instantiate, :update, :destroy]
  
  # GET /api/v1/templates
  def index
    templates = JourneyTemplate.published.includes(:user)
    
    # Apply filters
    templates = templates.where(category: params[:category]) if params[:category].present?
    templates = templates.where(industry: params[:industry]) if params[:industry].present?
    templates = templates.where('name ILIKE ? OR description ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    # Filter by template type
    if params[:template_type].present?
      templates = templates.where("metadata ->> 'template_type' = ?", params[:template_type])
    end
    
    # Filter by difficulty level
    if params[:difficulty].present?
      templates = templates.where("metadata ->> 'difficulty' = ?", params[:difficulty])
    end
    
    # Apply sorting
    case params[:sort_by]
    when 'name'
      templates = templates.order(:name)
    when 'category'
      templates = templates.order(:category, :name)
    when 'popularity'
      templates = templates.order(usage_count: :desc, name: :asc)
    when 'rating'
      templates = templates.order('metadata->>\'rating\' DESC NULLS LAST', :name)
    when 'created_at'
      templates = templates.order(:created_at)
    else
      templates = templates.order(:name)
    end
    
    paginate_and_render(templates, serializer: method(:serialize_template_summary))
  end
  
  # GET /api/v1/templates/:id
  def show
    render_success(data: serialize_template_detail(@template))
  end
  
  # POST /api/v1/templates
  def create
    template = current_user.journey_templates.build(template_params)
    
    if template.save
      render_success(
        data: serialize_template_detail(template),
        message: 'Template created successfully',
        status: :created
      )
    else
      render_error(
        message: 'Failed to create template',
        errors: template.errors.as_json
      )
    end
  end
  
  # PUT /api/v1/templates/:id
  def update
    # Only allow template owner to update
    unless @template.user == current_user
      return render_error(message: 'Access denied', status: :forbidden)
    end
    
    if @template.update(template_params)
      render_success(
        data: serialize_template_detail(@template),
        message: 'Template updated successfully'
      )
    else
      render_error(
        message: 'Failed to update template',
        errors: @template.errors.as_json
      )
    end
  end
  
  # DELETE /api/v1/templates/:id
  def destroy
    # Only allow template owner to delete
    unless @template.user == current_user
      return render_error(message: 'Access denied', status: :forbidden)
    end
    
    @template.destroy!
    render_success(message: 'Template deleted successfully')
  end
  
  # POST /api/v1/templates/:id/instantiate
  def instantiate
    instantiation_params = params.permit(:name, :description, :campaign_id, customizations: {})
    
    begin
      journey = @template.instantiate_for_user(current_user, instantiation_params)
      
      # Increment usage count
      @template.increment!(:usage_count)
      
      render_success(
        data: serialize_instantiated_journey(journey),
        message: 'Template instantiated successfully',
        status: :created
      )
    rescue => e
      render_error(message: "Failed to instantiate template: #{e.message}")
    end
  end
  
  # POST /api/v1/templates/:id/clone
  def clone
    begin
      new_template = @template.dup
      new_template.user = current_user
      new_template.name = "#{@template.name} (Copy)"
      new_template.is_public = false
      new_template.status = 'draft'
      new_template.usage_count = 0
      new_template.save!
      
      render_success(
        data: serialize_template_detail(new_template),
        message: 'Template cloned successfully',
        status: :created
      )
    rescue => e
      render_error(message: "Failed to clone template: #{e.message}")
    end
  end
  
  # GET /api/v1/templates/categories
  def categories
    categories = JourneyTemplate.published.distinct.pluck(:category).compact.sort
    render_success(data: categories)
  end
  
  # GET /api/v1/templates/industries
  def industries
    industries = JourneyTemplate.published.distinct.pluck(:industry).compact.sort
    render_success(data: industries)
  end
  
  # GET /api/v1/templates/popular
  def popular
    limit = [params[:limit].to_i, 1].max
    limit = [limit, 50].min # Cap at 50
    
    templates = JourneyTemplate.published
      .order(usage_count: :desc, name: :asc)
      .limit(limit)
    
    render_success(data: templates.map { |t| serialize_template_summary(t) })
  end
  
  # GET /api/v1/templates/recommended
  def recommended
    # Basic recommendation based on user's journey types and industries
    user_campaign_types = current_user.journeys.distinct.pluck(:campaign_type).compact
    user_industries = current_user.journeys.joins(:campaign).distinct.pluck('campaigns.industry').compact
    
    recommendations = JourneyTemplate.published
    
    if user_campaign_types.any?
      recommendations = recommendations.where(
        "metadata ->> 'recommended_for' ?| array[?]",
        user_campaign_types
      )
    end
    
    if user_industries.any?
      recommendations = recommendations.where(industry: user_industries)
    end
    
    # Fallback to popular templates if no specific recommendations
    if recommendations.empty?
      recommendations = JourneyTemplate.published.order(usage_count: :desc)
    end
    
    limit = [params[:limit].to_i, 10].max
    limit = [limit, 20].min
    
    render_success(
      data: recommendations.limit(limit).map { |t| serialize_template_summary(t) }
    )
  end
  
  # POST /api/v1/templates/:id/rate
  def rate
    rating = params[:rating].to_f
    comment = params[:comment]
    
    unless (1..5).include?(rating)
      return render_error(message: 'Rating must be between 1 and 5')
    end
    
    # Store rating in template metadata
    ratings = @template.metadata['ratings'] || []
    ratings << {
      user_id: current_user.id,
      rating: rating,
      comment: comment,
      created_at: Time.current
    }
    
    @template.metadata['ratings'] = ratings
    
    # Calculate average rating
    avg_rating = ratings.sum { |r| r['rating'] } / ratings.count.to_f
    @template.metadata['rating'] = avg_rating.round(2)
    
    @template.save!
    
    render_success(
      data: { rating: avg_rating, total_ratings: ratings.count },
      message: 'Rating submitted successfully'
    )
  end
  
  private
  
  def set_template
    @template = JourneyTemplate.find(params[:id])
  end
  
  def template_params
    params.require(:template).permit(
      :name, :description, :category, :industry, :is_public, :status,
      steps_template: [], metadata: {}
    )
  end
  
  def serialize_template_summary(template)
    {
      id: template.id,
      name: template.name,
      description: template.description,
      category: template.category,
      industry: template.industry,
      author: template.user.name,
      usage_count: template.usage_count,
      rating: template.metadata['rating'],
      total_ratings: (template.metadata['ratings'] || []).count,
      difficulty: template.metadata['difficulty'],
      estimated_duration: template.metadata['estimated_duration'],
      step_count: (template.steps_template || []).count,
      created_at: template.created_at,
      updated_at: template.updated_at
    }
  end
  
  def serialize_template_detail(template)
    {
      id: template.id,
      name: template.name,
      description: template.description,
      category: template.category,
      industry: template.industry,
      is_public: template.is_public,
      status: template.status,
      author: {
        id: template.user.id,
        name: template.user.name
      },
      usage_count: template.usage_count,
      rating: template.metadata['rating'],
      total_ratings: (template.metadata['ratings'] || []).count,
      steps_template: template.steps_template,
      metadata: template.metadata,
      version: template.version,
      created_at: template.created_at,
      updated_at: template.updated_at
    }
  end
  
  def serialize_instantiated_journey(journey)
    {
      id: journey.id,
      name: journey.name,
      description: journey.description,
      status: journey.status,
      template_id: journey.metadata['template_id'],
      created_at: journey.created_at
    }
  end
end