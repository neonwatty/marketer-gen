class Api::V1::PersonasController < Api::V1::BaseController
  before_action :set_persona, only: [:show, :update, :destroy, :campaigns, :performance]
  
  # GET /api/v1/personas
  def index
    personas = current_user.personas.includes(:campaigns)
    
    # Apply filters
    personas = personas.where('age_range && ?', params[:age_range]) if params[:age_range].present?
    personas = personas.where('location ILIKE ?', "%#{params[:location]}%") if params[:location].present?
    personas = personas.where('industry ILIKE ?', "%#{params[:industry]}%") if params[:industry].present?
    
    # Apply search
    if params[:search].present?
      personas = personas.where(
        'name ILIKE ? OR description ILIKE ?',
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end
    
    # Apply sorting
    case params[:sort_by]
    when 'name'
      personas = personas.order(:name)
    when 'age_range'
      personas = personas.order(:age_range)
    when 'location'
      personas = personas.order(:location)
    when 'created_at'
      personas = personas.order(:created_at)
    else
      personas = personas.order(:name)
    end
    
    paginate_and_render(personas, serializer: method(:serialize_persona_summary))
  end
  
  # GET /api/v1/personas/:id
  def show
    render_success(data: serialize_persona_detail(@persona))
  end
  
  # POST /api/v1/personas
  def create
    persona = current_user.personas.build(persona_params)
    
    if persona.save
      render_success(
        data: serialize_persona_detail(persona),
        message: 'Persona created successfully',
        status: :created
      )
    else
      render_error(
        message: 'Failed to create persona',
        errors: persona.errors.as_json
      )
    end
  end
  
  # PUT /api/v1/personas/:id
  def update
    if @persona.update(persona_params)
      render_success(
        data: serialize_persona_detail(@persona),
        message: 'Persona updated successfully'
      )
    else
      render_error(
        message: 'Failed to update persona',
        errors: @persona.errors.as_json
      )
    end
  end
  
  # DELETE /api/v1/personas/:id
  def destroy
    if @persona.campaigns.any?
      render_error(
        message: 'Cannot delete persona with associated campaigns',
        code: 'PERSONA_IN_USE'
      )
    else
      @persona.destroy!
      render_success(message: 'Persona deleted successfully')
    end
  end
  
  # GET /api/v1/personas/:id/campaigns
  def campaigns
    campaigns = @persona.campaigns.includes(:journeys)
    
    # Apply filters
    campaigns = campaigns.where(status: params[:status]) if params[:status].present?
    campaigns = campaigns.where(campaign_type: params[:campaign_type]) if params[:campaign_type].present?
    
    paginate_and_render(campaigns, serializer: method(:serialize_campaign_for_persona))
  end
  
  # GET /api/v1/personas/:id/performance
  def performance
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    
    # Get campaigns and journeys associated with this persona
    campaigns = @persona.campaigns.includes(:journeys)
    journeys = campaigns.flat_map(&:journeys)
    
    performance_data = {
      summary: calculate_persona_summary(@persona, journeys, days),
      campaign_performance: calculate_persona_campaign_performance(campaigns, days),
      journey_performance: calculate_persona_journey_performance(journeys, days),
      engagement_patterns: calculate_persona_engagement_patterns(@persona, days),
      conversion_insights: calculate_persona_conversion_insights(@persona, days),
      demographic_insights: calculate_demographic_insights(@persona),
      recommendations: generate_persona_recommendations(@persona, performance_data)
    }
    
    render_success(data: performance_data)
  end
  
  # POST /api/v1/personas/:id/clone
  def clone
    begin
      new_persona = @persona.dup
      new_persona.name = "#{@persona.name} (Copy)"
      new_persona.save!
      
      render_success(
        data: serialize_persona_detail(new_persona),
        message: 'Persona cloned successfully',
        status: :created
      )
    rescue => e
      render_error(message: "Failed to clone persona: #{e.message}")
    end
  end
  
  # GET /api/v1/personas/templates
  def templates
    # Predefined persona templates
    templates = [
      {
        name: 'Young Professional',
        age_range: '25-35',
        location: 'Urban',
        demographic_data: {
          income_range: '$50,000-$75,000',
          education: 'College Graduate',
          employment: 'Full-time Professional'
        },
        psychographic_data: {
          interests: ['Career Growth', 'Technology', 'Fitness'],
          values: ['Work-life Balance', 'Innovation', 'Achievement'],
          lifestyle: 'Fast-paced, Digital-first'
        }
      },
      {
        name: 'Family-Oriented Parent',
        age_range: '30-45',
        location: 'Suburban',
        demographic_data: {
          income_range: '$60,000-$100,000',
          education: 'College Graduate',
          family_status: 'Married with Children'
        },
        psychographic_data: {
          interests: ['Family Activities', 'Home Improvement', 'Education'],
          values: ['Family', 'Security', 'Quality'],
          lifestyle: 'Family-focused, Value-conscious'
        }
      },
      {
        name: 'Small Business Owner',
        age_range: '35-55',
        location: 'Various',
        demographic_data: {
          income_range: '$75,000-$150,000',
          education: 'College/Trade School',
          employment: 'Business Owner'
        },
        psychographic_data: {
          interests: ['Business Growth', 'Networking', 'Industry Trends'],
          values: ['Independence', 'Success', 'Innovation'],
          lifestyle: 'Busy, Results-oriented'
        }
      }
    ]
    
    render_success(data: templates)
  end
  
  # POST /api/v1/personas/from_template
  def create_from_template
    template_data = params.require(:template).permit!
    
    persona = current_user.personas.build(
      name: template_data[:name],
      description: "Created from #{template_data[:name]} template",
      age_range: template_data[:age_range],
      location: template_data[:location],
      demographic_data: template_data[:demographic_data] || {},
      psychographic_data: template_data[:psychographic_data] || {}
    )
    
    if persona.save
      render_success(
        data: serialize_persona_detail(persona),
        message: 'Persona created from template successfully',
        status: :created
      )
    else
      render_error(
        message: 'Failed to create persona from template',
        errors: persona.errors.as_json
      )
    end
  end
  
  # GET /api/v1/personas/analytics_overview
  def analytics_overview
    days = [params[:days].to_i, 30].max
    days = [days, 365].min
    
    personas = current_user.personas.includes(:campaigns)
    
    overview_data = {
      total_personas: personas.count,
      active_personas: personas.joins(:campaigns).where(campaigns: { status: 'active' }).distinct.count,
      top_performing: find_top_performing_personas(5, days),
      demographic_breakdown: calculate_demographic_breakdown(personas),
      usage_statistics: calculate_persona_usage_statistics(personas, days)
    }
    
    render_success(data: overview_data)
  end
  
  private
  
  def set_persona
    @persona = current_user.personas.find(params[:id])
  end
  
  def persona_params
    params.require(:persona).permit(
      :name, :description, :age_range, :location, :industry,
      demographic_data: {}, psychographic_data: {}, behavioral_data: {}
    )
  end
  
  def serialize_persona_summary(persona)
    {
      id: persona.id,
      name: persona.name,
      description: persona.description,
      age_range: persona.age_range,
      location: persona.location,
      industry: persona.industry,
      campaign_count: persona.campaigns.count,
      created_at: persona.created_at,
      updated_at: persona.updated_at
    }
  end
  
  def serialize_persona_detail(persona)
    {
      id: persona.id,
      name: persona.name,
      description: persona.description,
      age_range: persona.age_range,
      location: persona.location,
      industry: persona.industry,
      demographic_data: persona.demographic_data,
      psychographic_data: persona.psychographic_data,
      behavioral_data: persona.behavioral_data,
      campaign_count: persona.campaigns.count,
      campaigns: persona.campaigns.limit(5).map { |c| serialize_campaign_for_persona(c) },
      created_at: persona.created_at,
      updated_at: persona.updated_at
    }
  end
  
  def serialize_campaign_for_persona(campaign)
    {
      id: campaign.id,
      name: campaign.name,
      campaign_type: campaign.campaign_type,
      status: campaign.status,
      journey_count: campaign.journeys.count
    }
  end
  
  def calculate_persona_summary(persona, journeys, days)
    {
      persona_name: persona.name,
      total_campaigns: persona.campaigns.count,
      total_journeys: journeys.count,
      performance_score: calculate_persona_performance_score(journeys, days)
    }
  end
  
  def calculate_persona_campaign_performance(campaigns, days)
    campaigns.map do |campaign|
      journeys = campaign.journeys
      avg_performance = journeys.map(&:latest_performance_score).compact
      avg_score = avg_performance.any? ? (avg_performance.sum.to_f / avg_performance.count).round(1) : 0
      
      {
        id: campaign.id,
        name: campaign.name,
        status: campaign.status,
        journey_count: journeys.count,
        average_performance_score: avg_score
      }
    end
  end
  
  def calculate_persona_journey_performance(journeys, days)
    journeys.map do |journey|
      {
        id: journey.id,
        name: journey.name,
        performance_score: journey.latest_performance_score,
        conversion_rate: journey.current_analytics&.conversion_rate || 0,
        status: journey.status
      }
    end
  end
  
  def calculate_persona_engagement_patterns(persona, days)
    # Analyze engagement patterns for this persona
    campaigns = persona.campaigns
    
    {
      preferred_journey_types: analyze_preferred_journey_types(campaigns),
      optimal_touchpoint_frequency: analyze_touchpoint_frequency(campaigns),
      engagement_peak_times: analyze_engagement_times(campaigns),
      channel_preferences: analyze_channel_preferences(campaigns)
    }
  end
  
  def calculate_persona_conversion_insights(persona, days)
    campaigns = persona.campaigns
    journeys = campaigns.flat_map(&:journeys)
    
    {
      average_conversion_rate: calculate_average_conversion_rate(journeys),
      conversion_triggers: identify_conversion_triggers(journeys),
      optimal_journey_length: calculate_optimal_journey_length(journeys),
      successful_touchpoints: identify_successful_touchpoints(journeys)
    }
  end
  
  def calculate_demographic_insights(persona)
    # Analyze how demographic factors influence performance
    {
      age_segment_performance: analyze_age_segment_performance(persona),
      location_impact: analyze_location_impact(persona),
      industry_relevance: analyze_industry_relevance(persona)
    }
  end
  
  def generate_persona_recommendations(persona, performance_data)
    recommendations = []
    
    # Generate recommendations based on performance data
    if performance_data[:summary][:performance_score] < 50
      recommendations << "Consider adjusting journey content to better match persona interests"
    end
    
    if persona.campaigns.count == 0
      recommendations << "Create campaigns targeting this persona to gather performance data"
    end
    
    recommendations
  end
  
  def find_top_performing_personas(limit, days)
    current_user.personas
      .joins(campaigns: { journeys: :journey_analytics })
      .group('personas.id, personas.name')
      .order('AVG(journey_analytics.conversion_rate) DESC')
      .limit(limit)
      .pluck('personas.id, personas.name, AVG(journey_analytics.conversion_rate)')
      .map { |id, name, rate| { id: id, name: name, conversion_rate: rate&.round(2) || 0 } }
  end
  
  def calculate_demographic_breakdown(personas)
    {
      age_ranges: personas.group(:age_range).count,
      locations: personas.group(:location).count,
      industries: personas.group(:industry).count
    }
  end
  
  def calculate_persona_usage_statistics(personas, days)
    active_campaigns = personas.joins(:campaigns).where(campaigns: { status: 'active' }).count
    
    {
      personas_with_active_campaigns: active_campaigns,
      average_campaigns_per_persona: personas.joins(:campaigns).group('personas.id').count.values.sum.to_f / personas.count,
      most_used_persona: personas.joins(:campaigns).group('personas.id, personas.name').count.max_by { |_, count| count }
    }
  end
  
  def calculate_persona_performance_score(journeys, days)
    return 0.0 if journeys.empty?
    
    scores = journeys.map(&:latest_performance_score).compact
    return 0.0 if scores.empty?
    
    (scores.sum.to_f / scores.count).round(1)
  end
  
  def analyze_preferred_journey_types(campaigns)
    # Placeholder for journey type analysis
    []
  end
  
  def analyze_touchpoint_frequency(campaigns)
    # Placeholder for touchpoint frequency analysis
    'weekly'
  end
  
  def analyze_engagement_times(campaigns)
    # Placeholder for engagement time analysis
    []
  end
  
  def analyze_channel_preferences(campaigns)
    # Placeholder for channel preference analysis
    []
  end
  
  def calculate_average_conversion_rate(journeys)
    return 0.0 if journeys.empty?
    
    rates = journeys.map { |j| j.current_analytics&.conversion_rate || 0 }
    (rates.sum.to_f / rates.count).round(2)
  end
  
  def identify_conversion_triggers(journeys)
    # Placeholder for conversion trigger analysis
    []
  end
  
  def calculate_optimal_journey_length(journeys)
    # Placeholder for optimal journey length calculation
    5
  end
  
  def identify_successful_touchpoints(journeys)
    # Placeholder for successful touchpoint identification
    []
  end
  
  def analyze_age_segment_performance(persona)
    # Placeholder for age segment analysis
    {}
  end
  
  def analyze_location_impact(persona)
    # Placeholder for location impact analysis
    {}
  end
  
  def analyze_industry_relevance(persona)
    # Placeholder for industry relevance analysis
    {}
  end
end