class BrandAdaptationsController < ApplicationController
  before_action :set_brand_identity
  before_action :set_brand_variant, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :archive, :test, :duplicate]
  before_action :set_persona, only: [:create, :update, :adapt_content, :analyze_compatibility]

  # GET /brand_identities/:brand_identity_id/brand_adaptations
  def index
    authorize BrandVariant, :index?
    @brand_variants = policy_scope(BrandVariant)
                        .where(brand_identity: @brand_identity)
                        .includes(:persona)
                        .order(:priority, :name)
    
    # Filter by status if provided
    @brand_variants = @brand_variants.where(status: params[:status]) if params[:status].present?
    
    # Filter by adaptation type if provided
    @brand_variants = @brand_variants.where(adaptation_type: params[:adaptation_type]) if params[:adaptation_type].present?
    
    # Filter by persona if provided
    @brand_variants = @brand_variants.where(persona_id: params[:persona_id]) if params[:persona_id].present?
    
    @adaptation_types = BrandVariant::ADAPTATION_TYPES
    @adaptation_contexts = BrandVariant::ADAPTATION_CONTEXTS
    @statuses = BrandVariant::STATUSES
    @personas = policy_scope(Persona).where(user: Current.user).order(:name)
    
    respond_to do |format|
      format.html
      format.json { render json: brand_variants_json(@brand_variants) }
    end
  end

  # GET /brand_identities/:brand_identity_id/brand_adaptations/:id
  def show
    authorize @brand_variant
    @performance_summary = @brand_variant.performance_summary
    @compatibility_score = calculate_persona_compatibility if @brand_variant.persona
    
    respond_to do |format|
      format.html
      format.json { render json: brand_variant_json(@brand_variant) }
    end
  end

  # GET /brand_identities/:brand_identity_id/brand_adaptations/new
  def new
    @brand_variant = @brand_identity.brand_variants.build
    authorize @brand_variant
    @personas = policy_scope(Persona).where(user: Current.user).order(:name)
    @adaptation_types = BrandVariant::ADAPTATION_TYPES
    @adaptation_contexts = BrandVariant::ADAPTATION_CONTEXTS
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations
  def create
    @brand_variant = @brand_identity.brand_variants.build(brand_variant_params)
    @brand_variant.user = Current.user
    authorize @brand_variant
    
    if @brand_variant.save
      flash[:notice] = "Brand variant created successfully."
      redirect_to [@brand_identity, @brand_variant]
    else
      @personas = policy_scope(Persona).where(user: Current.user).order(:name)
      @adaptation_types = BrandVariant::ADAPTATION_TYPES
      @adaptation_contexts = BrandVariant::ADAPTATION_CONTEXTS
      render :new, status: :unprocessable_entity
    end
  end

  # GET /brand_identities/:brand_identity_id/brand_adaptations/:id/edit
  def edit
    authorize @brand_variant
    @personas = policy_scope(Persona).where(user: Current.user).order(:name)
    @adaptation_types = BrandVariant::ADAPTATION_TYPES
    @adaptation_contexts = BrandVariant::ADAPTATION_CONTEXTS
  end

  # PATCH/PUT /brand_identities/:brand_identity_id/brand_adaptations/:id
  def update
    authorize @brand_variant
    
    if @brand_variant.update(brand_variant_params)
      flash[:notice] = "Brand variant updated successfully."
      redirect_to [@brand_identity, @brand_variant]
    else
      @personas = policy_scope(Persona).where(user: Current.user).order(:name)
      @adaptation_types = BrandVariant::ADAPTATION_TYPES
      @adaptation_contexts = BrandVariant::ADAPTATION_CONTEXTS
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /brand_identities/:brand_identity_id/brand_adaptations/:id
  def destroy
    authorize @brand_variant
    @brand_variant.destroy
    flash[:notice] = "Brand variant deleted successfully."
    redirect_to brand_identity_brand_adaptations_path(@brand_identity)
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations/:id/activate
  def activate
    authorize @brand_variant, :activate?
    @brand_variant.activate!
    
    respond_to do |format|
      format.html do
        flash[:notice] = "Brand variant activated successfully."
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { status: 'activated', message: 'Brand variant activated successfully.' } }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html do
        flash[:alert] = "Failed to activate brand variant: #{e.message}"
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations/:id/deactivate
  def deactivate
    authorize @brand_variant, :deactivate?
    @brand_variant.deactivate!
    
    respond_to do |format|
      format.html do
        flash[:notice] = "Brand variant deactivated successfully."
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { status: 'deactivated', message: 'Brand variant deactivated successfully.' } }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html do
        flash[:alert] = "Failed to deactivate brand variant: #{e.message}"
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations/:id/archive
  def archive
    authorize @brand_variant, :archive?
    @brand_variant.archive!
    
    respond_to do |format|
      format.html do
        flash[:notice] = "Brand variant archived successfully."
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { status: 'archived', message: 'Brand variant archived successfully.' } }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html do
        flash[:alert] = "Failed to archive brand variant: #{e.message}"
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations/:id/test
  def test
    authorize @brand_variant, :test?
    @brand_variant.start_testing!
    
    respond_to do |format|
      format.html do
        flash[:notice] = "Brand variant testing started."
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { status: 'testing', message: 'Brand variant testing started.' } }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html do
        flash[:alert] = "Failed to start testing: #{e.message}"
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations/:id/duplicate
  def duplicate
    authorize @brand_variant, :duplicate?
    
    begin
      # Create a duplicate with modified attributes
      duplicate_attributes = @brand_variant.attributes.except('id', 'created_at', 'updated_at', 'usage_count', 'last_used_at')
      duplicate_attributes['name'] = "#{@brand_variant.name} (Copy)"
      duplicate_attributes['status'] = 'draft'
      duplicate_attributes['effectiveness_score'] = nil
      duplicate_attributes['activated_at'] = nil
      duplicate_attributes['archived_at'] = nil
      duplicate_attributes['testing_started_at'] = nil
      
      @duplicate_variant = @brand_identity.brand_variants.create!(duplicate_attributes)
      
      respond_to do |format|
        format.html do
          flash[:notice] = "Brand variant duplicated successfully."
          redirect_to [@brand_identity, @duplicate_variant]
        end
        format.json { render json: brand_variant_json(@duplicate_variant), status: :created }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html do
          flash[:alert] = "Failed to duplicate brand variant: #{e.message}"
          redirect_to [@brand_identity, @brand_variant]
        end
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations/adapt_content
  def adapt_content
    authorize BrandVariant, :adapt_content?
    
    content = params[:content]
    adaptation_params = params[:adaptation_params] || {}
    
    if content.blank?
      respond_to do |format|
        format.html do
          flash[:alert] = "Content is required for adaptation."
          redirect_back_or_to brand_identity_brand_adaptations_path(@brand_identity)
        end
        format.json { render json: { error: "Content is required" }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      result = BrandAdaptationService.call(
        user: Current.user,
        brand_identity: @brand_identity,
        content: content,
        adaptation_params: adaptation_params
      )
      
      if result[:success]
        respond_to do |format|
          format.html do
            flash[:notice] = "Content adapted successfully."
            redirect_to brand_identity_brand_adaptations_path(@brand_identity), 
                       notice: "Adapted content: #{result[:data][:adapted_content].truncate(100)}"
          end
          format.json { render json: result[:data] }
        end
      else
        respond_to do |format|
          format.html do
            flash[:alert] = "Failed to adapt content: #{result[:error]}"
            redirect_back_or_to brand_identity_brand_adaptations_path(@brand_identity)
          end
          format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html do
          flash[:alert] = "An error occurred while adapting content: #{e.message}"
          redirect_back_or_to brand_identity_brand_adaptations_path(@brand_identity)
        end
        format.json { render json: { error: e.message }, status: :internal_server_error }
      end
    end
  end

  # POST /brand_identities/:brand_identity_id/brand_adaptations/analyze_consistency
  def analyze_consistency
    authorize BrandVariant, :analyze_consistency?
    
    content_samples = params[:content_samples]
    
    if content_samples.blank? || !content_samples.is_a?(Array)
      respond_to do |format|
        format.html do
          flash[:alert] = "Content samples are required for analysis."
          redirect_back_or_to brand_identity_brand_adaptations_path(@brand_identity)
        end
        format.json { render json: { error: "Content samples are required" }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      result = BrandAdaptationService.analyze_brand_consistency(
        user: Current.user,
        brand_identity: @brand_identity,
        content_samples: content_samples
      )
      
      if result[:success]
        respond_to do |format|
          format.html do
            flash[:notice] = "Brand consistency analysis completed."
            redirect_to brand_identity_brand_adaptations_path(@brand_identity)
          end
          format.json { render json: result[:data] }
        end
      else
        respond_to do |format|
          format.html do
            flash[:alert] = "Failed to analyze consistency: #{result[:error]}"
            redirect_back_or_to brand_identity_brand_adaptations_path(@brand_identity)
          end
          format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html do
          flash[:alert] = "An error occurred during analysis: #{e.message}"
          redirect_back_or_to brand_identity_brand_adaptations_path(@brand_identity)
        end
        format.json { render json: { error: e.message }, status: :internal_server_error }
      end
    end
  end

  # GET /brand_identities/:brand_identity_id/brand_adaptations/analyze_compatibility
  def analyze_compatibility
    authorize BrandVariant, :analyze_compatibility?
    
    if @persona.nil?
      respond_to do |format|
        format.html do
          flash[:alert] = "Persona is required for compatibility analysis."
          redirect_back_or_to brand_identity_brand_adaptations_path(@brand_identity)
        end
        format.json { render json: { error: "Persona is required" }, status: :unprocessable_entity }
      end
      return
    end
    
    # Find all brand variants for this brand identity
    brand_variants = policy_scope(BrandVariant)
                       .where(brand_identity: @brand_identity)
                       .active
    
    compatibility_results = brand_variants.map do |variant|
      {
        variant_id: variant.id,
        variant_name: variant.name,
        adaptation_type: variant.adaptation_type,
        compatibility_score: variant.compatibility_score_with(@persona),
        performance_summary: variant.performance_summary
      }
    end
    
    # Sort by compatibility score descending
    compatibility_results.sort_by! { |result| -result[:compatibility_score] }
    
    respond_to do |format|
      format.html do
        @compatibility_results = compatibility_results
        render :analyze_compatibility
      end
      format.json { render json: { persona: persona_json(@persona), compatibility_results: compatibility_results } }
    end
  end

  # PATCH /brand_identities/:brand_identity_id/brand_adaptations/:id/update_effectiveness
  def update_effectiveness
    authorize @brand_variant, :update_effectiveness?
    
    effectiveness_score = params[:effectiveness_score]&.to_f
    
    if effectiveness_score.nil? || effectiveness_score < 0.0 || effectiveness_score > 10.0
      respond_to do |format|
        format.html do
          flash[:alert] = "Effectiveness score must be between 0.0 and 10.0."
          redirect_to [@brand_identity, @brand_variant]
        end
        format.json { render json: { error: "Invalid effectiveness score" }, status: :unprocessable_entity }
      end
      return
    end
    
    @brand_variant.update_effectiveness!(effectiveness_score)
    
    respond_to do |format|
      format.html do
        flash[:notice] = "Effectiveness score updated successfully."
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { effectiveness_score: effectiveness_score, updated_at: @brand_variant.last_measured_at } }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html do
        flash[:alert] = "Failed to update effectiveness score: #{e.message}"
        redirect_to [@brand_identity, @brand_variant]
      end
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_brand_identity
    @brand_identity = BrandIdentity.find(params[:brand_identity_id])
    authorize @brand_identity, :show?
  rescue Pundit::NotAuthorizedError
    flash[:alert] = "You are not authorized to access this brand identity."
    redirect_to brand_identities_path
  end

  def set_brand_variant
    @brand_variant = @brand_identity.brand_variants.find(params[:id])
  end

  def set_persona
    if params[:persona_id].present?
      @persona = policy_scope(Persona).find(params[:persona_id])
    elsif brand_variant_params && brand_variant_params[:persona_id].present?
      @persona = policy_scope(Persona).find(brand_variant_params[:persona_id])
    end
  end

  def brand_variant_params
    params.require(:brand_variant).permit(
      :name, :description, :adaptation_context, :adaptation_type, :status, :priority,
      :persona_id, :effectiveness_score,
      adaptation_rules: {},
      brand_voice_adjustments: {},
      messaging_variations: {},
      visual_guidelines: {},
      channel_specifications: {},
      audience_targeting: {},
      performance_metrics: {},
      a_b_test_results: {}
    )
  end

  def calculate_persona_compatibility
    return 0.0 unless @brand_variant.persona
    @brand_variant.compatibility_score_with(@brand_variant.persona)
  end

  def brand_variants_json(brand_variants)
    {
      brand_variants: brand_variants.map { |variant| brand_variant_summary_json(variant) },
      pagination: pagination_meta(brand_variants),
      filters: {
        adaptation_types: BrandVariant::ADAPTATION_TYPES,
        adaptation_contexts: BrandVariant::ADAPTATION_CONTEXTS,
        statuses: BrandVariant::STATUSES
      }
    }
  end

  def brand_variant_json(brand_variant)
    {
      id: brand_variant.id,
      name: brand_variant.name,
      description: brand_variant.description,
      adaptation_context: brand_variant.adaptation_context,
      adaptation_type: brand_variant.adaptation_type,
      status: brand_variant.status,
      priority: brand_variant.priority,
      effectiveness_score: brand_variant.effectiveness_score,
      usage_count: brand_variant.usage_count,
      last_used_at: brand_variant.last_used_at,
      created_at: brand_variant.created_at,
      updated_at: brand_variant.updated_at,
      persona: brand_variant.persona ? persona_summary_json(brand_variant.persona) : nil,
      adaptation_rules: brand_variant.parsed_adaptation_rules,
      brand_voice_adjustments: brand_variant.parsed_brand_voice_adjustments,
      messaging_variations: brand_variant.parsed_messaging_variations,
      visual_guidelines: brand_variant.parsed_visual_guidelines,
      channel_specifications: brand_variant.parsed_channel_specifications,
      audience_targeting: brand_variant.parsed_audience_targeting,
      performance_metrics: brand_variant.parsed_performance_metrics,
      performance_summary: brand_variant.performance_summary
    }
  end

  def brand_variant_summary_json(brand_variant)
    {
      id: brand_variant.id,
      name: brand_variant.name,
      adaptation_context: brand_variant.adaptation_context,
      adaptation_type: brand_variant.adaptation_type,
      status: brand_variant.status,
      priority: brand_variant.priority,
      effectiveness_score: brand_variant.effectiveness_score,
      usage_count: brand_variant.usage_count,
      last_used_at: brand_variant.last_used_at,
      persona: brand_variant.persona ? persona_summary_json(brand_variant.persona) : nil
    }
  end

  def persona_json(persona)
    {
      id: persona.id,
      name: persona.name,
      description: persona.description,
      characteristics: persona.characteristics,
      demographics: persona.parse_demographic_data,
      goals: persona.parse_goals_data,
      pain_points: persona.parse_pain_points_data,
      preferred_channels: persona.parse_preferred_channels,
      content_preferences: persona.parse_content_preferences,
      behavioral_traits: persona.parse_behavioral_traits
    }
  end

  def persona_summary_json(persona)
    {
      id: persona.id,
      name: persona.name,
      description: persona.description
    }
  end

  def pagination_meta(collection)
    # This would be implemented if using a pagination gem like Kaminari
    # For now, return basic info
    {
      total_count: collection.respond_to?(:total_count) ? collection.total_count : collection.count,
      current_page: 1,
      per_page: collection.respond_to?(:limit_value) ? collection.limit_value : collection.count,
      total_pages: 1
    }
  end
end