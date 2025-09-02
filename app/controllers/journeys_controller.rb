class JourneysController < ApplicationController
  before_action :require_authentication
  before_action :set_journey, only: [:show, :edit, :update, :destroy, :reorder_steps, :suggestions, :duplicate, :archive, 
                                       :apply_ai_suggestion, :ai_feedback, :ai_optimization_insights, :enable_ai_optimization, :generate_with_ai]

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
    
    # Analytics data - optimized with a single query
    journey_counts = @journeys.group(:status).count
    @analytics = {
      total_journeys: @journeys.count,
      active_journeys: journey_counts['active'] || 0,
      completed_journeys: journey_counts['completed'] || 0,
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

  def select_template
    authorize Journey
    
    # Get filter parameters
    @filters = {
      campaign_type: params[:campaign_type],
      category: params[:category],
      industry: params[:industry],
      complexity_level: params[:complexity_level],
      search: params[:search]
    }.compact
    
    # Start with all templates
    @templates = JourneyTemplate.order(:name)
    
    # Apply filters
    @templates = @templates.filter_by_criteria(@filters)
    @templates = @templates.search_by_metadata(@filters[:search]) if @filters[:search].present?
    
    # Get guided questions based on current state
    @guided_questions = build_guided_questions(@filters)
    
    # Get filter options for dropdowns
    @filter_options = {
      campaign_types: JourneyTemplate::CAMPAIGN_TYPES,
      categories: JourneyTemplate::CATEGORIES,
      industries: JourneyTemplate::INDUSTRIES,
      complexity_levels: JourneyTemplate::COMPLEXITY_LEVELS
    }
    
    # Analytics for template selection insights
    @template_analytics = {
      total_templates: @templates.count,
      by_campaign_type: @templates.group(:campaign_type).count,
      by_complexity: @templates.group(:complexity_level).count,
      recommended_count: @templates.for_beginner.count
    }
    
    respond_to do |format|
      format.html
      format.turbo_stream { render :filter_templates }
    end
  end

  def template_preview
    authorize Journey
    
    begin
      @template = JourneyTemplate.find(params[:template_id])
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { head :not_found }
        format.turbo_stream { head :not_found }
      end
      return
    end
    
    # Build preview journey data
    @preview_data = {
      template: @template,
      stages: @template.template_data["stages"] || [],
      steps: @template.template_data["steps"] || [],
      metadata: @template.template_data["metadata"] || {},
      timeline: @template.get_timeline,
      key_metrics: @template.get_key_metrics,
      target_audience: @template.get_target_audience
    }
    
    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream { render :template_preview }
    end
  end

  def create_from_template
    @template = JourneyTemplate.find(params[:template_id])
    authorize Journey
    
    # Get journey attributes from form
    journey_attributes = {
      name: params[:journey_name] || "#{@template.name} Journey",
      description: params[:journey_description] || @template.description,
      template_type: params[:template_type] || 'custom'
    }
    
    # Create journey from template
    @journey = @template.create_journey_for_user(Current.user, journey_attributes)
    
    if @journey.persisted?
      # Store template selection context for analytics
      @journey.update_column(:metadata, 
        (@journey.metadata || {}).merge({
          template_source: @template.id,
          template_name: @template.name,
          selection_context: {
            campaign_type: @template.campaign_type,
            complexity_level: @template.complexity_level,
            created_via: 'template_selection'
          }
        })
      )
      
      redirect_to edit_journey_path(@journey), 
                  notice: "Journey created from template '#{@template.name}'. You can now customize it."
    else
      redirect_to select_template_journeys_path, 
                  alert: "Failed to create journey from template. Please try again."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to select_template_journeys_path, alert: "Template not found."
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
    
    # Get suggestions with safe limit parameter handling
    limit = params[:limit].is_a?(Array) ? params[:limit].first : params[:limit]
    limit = limit&.to_i || 5
    
    # Check if AI is enabled and brand identity exists
    ai_powered = Rails.application.config.ai_journey_suggestions_enabled && 
                 Current.user.active_brand_identity.present?
    
    suggestions = if ai_powered
      # Use AI-powered suggestions with brand context
      ai_service = JourneyAiService.new(@journey, Current.user)
      ai_result = ai_service.generate_intelligent_suggestions(limit: limit, stage: current_stage)
      
      # Extract suggestions from the result
      ai_suggestions = if ai_result.is_a?(Hash) && ai_result[:suggestions]
        ai_result[:suggestions]
      elsif ai_result.is_a?(Array)
        ai_result
      else
        []
      end
      
      # Track AI generation for analytics
      track_ai_suggestion_generation(ai_suggestions) if ai_suggestions.any?
      
      ai_suggestions
    else
      # Fall back to rule-based suggestions
      suggestion_service = JourneySuggestionService.new(
        campaign_type: @journey.campaign_type,
        template_type: @journey.template_type,
        current_stage: current_stage,
        existing_steps: existing_steps,
        user: Current.user,
        journey: @journey
      )
      
      suggestions = suggestion_service.suggest_steps(limit: limit)
      
      # Enhance suggestions with additional details
      suggestions.map do |suggestion|
        channels = suggestion_service.suggest_channels_for_step(suggestion[:step_type])
        content = suggestion_service.suggest_content_for_step(suggestion[:step_type], current_stage)
        
        suggestion.merge(
          suggested_channels: channels,
          content_suggestions: content
        )
      end
    end
    
    render json: {
      suggestions: suggestions,
      current_stage: current_stage,
      available_stages: @journey.stages,
      campaign_type: @journey.campaign_type,
      ai_powered: ai_powered
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

  # AI-powered journey actions

  def apply_ai_suggestion
    authorize @journey, :update?
    
    suggestion_data = params[:suggestion_data] || params[:suggestion]
    
    if suggestion_data.blank?
      return render json: { error: 'No suggestion data provided' }, status: :bad_request
    end
    
    begin
      suggestion = JSON.parse(suggestion_data) rescue suggestion_data
      
      # Create journey step from AI suggestion
      step = @journey.journey_steps.build(
        title: suggestion['title'],
        description: suggestion['description'],
        step_type: suggestion['step_type'],
        channel: suggestion['channel'] || suggestion['channels']&.first,
        ai_generated: true,
        brand_compliance_score: suggestion['brand_compliance_score'],
        ai_metadata: {
          original_suggestion: suggestion,
          applied_at: Time.current,
          model_used: Rails.application.config.ai_journey_models[:suggestions]
        }
      )
      
      if step.save
        # Track AI application
        @journey.increment!(:ai_applied_count)
        
        # Record in AI suggestions table
        record_ai_suggestion_application(suggestion, step)
        
        respond_to do |format|
          format.html { redirect_to @journey, notice: 'AI suggestion applied successfully!' }
          format.json { render json: { success: true, step_id: step.id } }
        end
      else
        respond_to do |format|
          format.html { redirect_to @journey, alert: "Failed to apply suggestion: #{step.errors.full_messages.join(', ')}" }
          format.json { render json: { error: step.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    rescue StandardError => e
      Rails.logger.error "Failed to apply AI suggestion: #{e.message}"
      respond_to do |format|
        format.html { redirect_to @journey, alert: 'Failed to apply suggestion. Please try again.' }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def ai_feedback
    authorize @journey, :show?
    
    suggestion_index = params[:suggestion_index]
    feedback = params[:feedback]
    
    if suggestion_index.blank? || feedback.blank?
      return render json: { error: 'Missing required parameters' }, status: :bad_request
    end
    
    # Record feedback for learning
    record_feedback(suggestion_index, feedback)
    
    render json: { success: true, message: 'Feedback recorded' }
  end

  def ai_optimization_insights
    authorize @journey, :show?
    
    begin
      ai_service = JourneyAiService.new(@journey, Current.user)
      insights = ai_service.analyze_and_optimize
      
      respond_to do |format|
        format.html { 
          @optimization_insights = insights
          render :optimization_insights 
        }
        format.json { render json: insights }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to generate optimization insights: #{e.message}"
      respond_to do |format|
        format.html { redirect_to @journey, alert: 'Failed to generate insights. Please try again.' }
        format.json { render json: { error: e.message }, status: :internal_server_error }
      end
    end
  end

  def enable_ai_optimization
    authorize @journey, :update?
    
    @journey.update!(ai_optimization_enabled: params[:enabled] == 'true')
    
    respond_to do |format|
      format.html { redirect_to @journey, notice: "AI optimization #{@journey.ai_optimization_enabled? ? 'enabled' : 'disabled'}." }
      format.json { render json: { enabled: @journey.ai_optimization_enabled? } }
    end
  end

  def generate_with_ai
    authorize @journey, :update?
    
    prompt = params[:prompt]
    
    if prompt.blank?
      return render json: { error: 'No prompt provided' }, status: :bad_request
    end
    
    begin
      # Use natural language to generate journey steps
      ai_service = JourneyAiService.new(@journey, Current.user)
      result = ai_service.generate_from_natural_language(prompt)
      
      if result[:success]
        respond_to do |format|
          format.html { redirect_to @journey, notice: 'Journey steps generated from your description!' }
          format.json { render json: result }
        end
      else
        respond_to do |format|
          format.html { redirect_to @journey, alert: "Generation failed: #{result[:error]}" }
          format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue StandardError => e
      Rails.logger.error "Failed to generate with AI: #{e.message}"
      respond_to do |format|
        format.html { redirect_to @journey, alert: 'Failed to generate journey. Please try again.' }
        format.json { render json: { error: e.message }, status: :internal_server_error }
      end
    end
  end

  def bulk_archive
    authorize Journey
    journey_ids = params[:ids] || []
    
    if journey_ids.empty?
      render json: { error: 'No journeys selected' }, status: :bad_request
      return
    end

    journeys = policy_scope(Journey).where(id: journey_ids)
    archived_count = 0
    failed_count = 0

    journeys.find_each do |journey|
      if journey.can_be_archived?
        journey.update(status: 'archived')
        archived_count += 1
      else
        failed_count += 1
      end
    end

    message = "#{archived_count} journeys archived successfully"
    message += ", #{failed_count} could not be archived" if failed_count > 0

    redirect_to journeys_path, notice: message
  end

  def bulk_duplicate
    authorize Journey
    journey_ids = params[:ids] || []
    
    if journey_ids.empty?
      render json: { error: 'No journeys selected' }, status: :bad_request
      return
    end

    journeys = policy_scope(Journey).where(id: journey_ids)
    duplicated_count = 0

    journeys.find_each do |journey|
      new_journey = journey.dup
      new_journey.name = "Copy of #{journey.name}"
      new_journey.status = 'draft'
      new_journey.user = Current.user
      
      if new_journey.save
        # Duplicate journey steps
        journey.journey_steps.find_each do |step|
          new_step = step.dup
          new_step.journey = new_journey
          new_step.save
        end
        duplicated_count += 1
      end
    end

    redirect_to journeys_path, notice: "#{duplicated_count} journeys duplicated successfully"
  end

  def bulk_delete
    authorize Journey
    journey_ids = params[:ids] || []
    
    if journey_ids.empty?
      render json: { error: 'No journeys selected' }, status: :bad_request
      return
    end

    journeys = policy_scope(Journey).where(id: journey_ids)
    deleted_count = journeys.destroy_all.count

    redirect_to journeys_path, notice: "#{deleted_count} journeys deleted successfully"
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

  def parse_timing(timing_string)
    return 'immediate' if timing_string.blank?
    
    case timing_string.downcase
    when /immediate/i then 'immediate'
    when /day|daily/i then 'time_based'
    when /week/i then 'time_based'
    when /trigger|event/i then 'event_based'
    else 'manual'
    end
  end

  def record_ai_suggestion_application(suggestion, step)
    # Record in database for learning
    if defined?(JourneyAiSuggestion)
      JourneyAiSuggestion.create!(
        journey: @journey,
        user: Current.user,
        brand_identity: Current.user.active_brand_identity,
        suggestion_type: suggestion['step_type'],
        content: suggestion,
        brand_compliance_score: { score: suggestion['brand_compliance_score'] },
        applied: true,
        user_feedback: 'accepted',
        llm_model_used: Rails.application.config.ai_journey_models[:suggestions]
      )
    end
  rescue StandardError => e
    Rails.logger.error "Failed to record AI suggestion: #{e.message}"
  end

  def record_feedback(suggestion_index, feedback)
    # Store feedback for future learning
    Rails.cache.write(
      "journey_ai_feedback_#{@journey.id}_#{suggestion_index}",
      { feedback: feedback, timestamp: Time.current },
      expires_in: 30.days
    )
  end

  def track_ai_suggestion_generation(suggestions)
    # Track AI suggestion generation for analytics
    return unless defined?(JourneyAiSuggestion)
    
    suggestions.each do |suggestion|
      begin
        JourneyAiSuggestion.create!(
          journey: @journey,
          user: Current.user,
          brand_identity: Current.user.active_brand_identity,
          suggestion_type: suggestion[:step_type],
          content: suggestion,
          brand_compliance_score: { score: suggestion[:brand_compliance_score] },
          applied: false,
          llm_model_used: Rails.application.config.ai_journey_models[:suggestions]
        )
      rescue StandardError => e
        Rails.logger.error "Failed to track AI suggestion: #{e.message}"
      end
    end
  end

  def set_journey
    @journey = policy_scope(Journey).find(params[:id])
  end

  def journey_params
    params.require(:journey).permit(:name, :description, :campaign_type, :status, :template_type, :target_audience, stages: [], metadata: {})
  end

  def calculate_average_completion_rate(journeys)
    return 0 if journeys.empty?
    
    completion_rates = journeys.map(&:completion_rate)
    completion_rates.sum / completion_rates.length
  end

  def build_guided_questions(current_filters)
    questions = []
    
    # Step 1: Campaign Type - Always first if not selected
    unless current_filters[:campaign_type].present?
      questions << {
        step: 1,
        type: 'campaign_type',
        question: "What type of campaign are you planning?",
        description: "This helps us recommend the most suitable templates for your goals.",
        options: JourneyTemplate::CAMPAIGN_TYPES.map { |type| 
          { 
            value: type, 
            label: type.humanize, 
            description: campaign_type_description(type),
            icon: campaign_type_icon(type)
          } 
        },
        required: true
      }
      return questions # Return early to focus on one question at a time
    end
    
    # Step 2: Experience Level - Show after campaign type is selected
    unless current_filters[:complexity_level].present?
      questions << {
        step: 2,
        type: 'complexity_level',
        question: "What's your experience level with #{current_filters[:campaign_type].humanize} campaigns?",
        description: "We'll show templates that match your comfort level.",
        options: JourneyTemplate::COMPLEXITY_LEVELS.map { |level|
          {
            value: level,
            label: level.humanize,
            description: complexity_description(level),
            icon: complexity_icon(level)
          }
        },
        required: false
      }
      return questions
    end
    
    # Step 3: Industry - Show for more specific recommendations
    unless current_filters[:industry].present?
      questions << {
        step: 3,
        type: 'industry',
        question: "Which industry best describes your business?",
        description: "This helps us show templates with relevant messaging and strategies.",
        options: JourneyTemplate::INDUSTRIES.map { |industry|
          {
            value: industry,
            label: industry.humanize,
            description: industry_description(industry)
          }
        },
        required: false,
        allow_skip: true
      }
      return questions
    end
    
    # Step 4: Category - Final refinement
    unless current_filters[:category].present?
      questions << {
        step: 4,
        type: 'category',
        question: "What's the primary focus of this campaign?",
        description: "Choose the main objective to see the most relevant templates.",
        options: JourneyTemplate::CATEGORIES.map { |category|
          {
            value: category,
            label: category.humanize,
            description: category_description(category)
          }
        },
        required: false,
        allow_skip: true
      }
    end
    
    questions
  end

  def campaign_type_description(type)
    descriptions = {
      'awareness' => 'Build brand recognition and reach new audiences',
      'consideration' => 'Nurture prospects who are evaluating your solution',
      'conversion' => 'Drive purchases or sign-ups from qualified leads',
      'retention' => 'Keep existing customers engaged and reduce churn',
      'upsell_cross_sell' => 'Increase revenue from current customers'
    }
    descriptions[type] || ''
  end

  def campaign_type_icon(type)
    icons = {
      'awareness' => 'eye',
      'consideration' => 'search',
      'conversion' => 'shopping-cart',
      'retention' => 'heart',
      'upsell_cross_sell' => 'trending-up'
    }
    icons[type] || 'target'
  end

  def complexity_description(level)
    descriptions = {
      'beginner' => 'New to this type of campaign - show me simple, proven approaches',
      'intermediate' => 'Some experience - I want templates with good customization options',
      'advanced' => 'Experienced marketer - show me sophisticated, multi-channel strategies',
      'expert' => 'Very experienced - I want complex, cutting-edge template approaches'
    }
    descriptions[level] || ''
  end

  def complexity_icon(level)
    icons = {
      'beginner' => 'play',
      'intermediate' => 'layers',
      'advanced' => 'zap',
      'expert' => 'award'
    }
    icons[level] || 'target'
  end

  def industry_description(industry)
    descriptions = {
      'technology' => 'Software, IT services, tech products',
      'healthcare' => 'Medical, wellness, health services',
      'finance' => 'Banking, insurance, financial services',
      'retail' => 'Consumer goods, physical products',
      'ecommerce' => 'Online stores, digital commerce',
      'saas' => 'Software as a Service, cloud platforms',
      'b2b' => 'Business-to-business services',
      'b2c' => 'Direct consumer marketing',
      'education' => 'Schools, training, educational services',
      'nonprofit' => 'Charitable organizations, causes'
    }
    descriptions[industry] || 'General business'
  end

  def category_description(category)
    descriptions = {
      'acquisition' => 'Focus on attracting new customers or users',
      'retention' => 'Keep existing customers engaged and loyal',
      'engagement' => 'Build deeper relationships with your audience',
      'conversion' => 'Turn prospects into paying customers',
      'lifecycle' => 'Guide customers through their entire journey',
      'nurturing' => 'Educate and build trust with potential buyers'
    }
    descriptions[category] || ''
  end
end