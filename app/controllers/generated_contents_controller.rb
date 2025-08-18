# frozen_string_literal: true

# Controller for managing generated content with CRUD operations, 
# version control, and approval workflows
class GeneratedContentsController < ApplicationController
  include Authentication
  
  before_action :require_authentication
  before_action :set_generated_content, only: [:show, :edit, :update, :destroy, :regenerate, :approve, :publish, :archive]
  before_action :set_campaign_plan, only: [:index, :new, :create, :generate]
  before_action :authorize_content, only: [:show, :edit, :update, :destroy, :regenerate, :approve, :publish, :archive]
  before_action :authorize_campaign_plan, only: [:index, :new, :create, :generate]

  # GET /campaign_plans/:campaign_plan_id/generated_contents
  # GET /generated_contents
  def index
    @generated_contents = content_scope
      .includes(:campaign_plan, :created_by, :approver, :original_content)
      .recent
    
    # Apply filters
    @generated_contents = apply_filters(@generated_contents)
    
    # Simple pagination fallback (limit results)
    @generated_contents = @generated_contents.limit(20)
    
    # For AJAX requests
    respond_to do |format|
      format.html
      format.json { render json: content_json_response(@generated_contents) }
    end
  end

  # GET /generated_contents/:id
  def show
    @version_history = @generated_content.version_history_chain
    @analytics = content_analytics(@generated_content)
    
    respond_to do |format|
      format.html
      format.json { render json: content_detail_json(@generated_content) }
    end
  end

  # GET /campaign_plans/:campaign_plan_id/generated_contents/new
  def new
    @generated_content = @campaign_plan.generated_contents.build
    @content_types = GeneratedContent::CONTENT_TYPES
    @format_variants = GeneratedContent::FORMAT_VARIANTS
    
    # Pre-populate with campaign context
    set_campaign_context(@generated_content)
  end

  # POST /campaign_plans/:campaign_plan_id/generated_contents
  def create
    @generated_content = @campaign_plan.generated_contents.build(content_params)
    @generated_content.created_by = Current.user
    @generated_content.status = 'draft'
    @generated_content.version_number = 1
    
    if @generated_content.save
      redirect_to @generated_content, notice: 'Content was successfully created.'
    else
      @content_types = GeneratedContent::CONTENT_TYPES
      @format_variants = GeneratedContent::FORMAT_VARIANTS
      render :new, status: :unprocessable_entity
    end
  end

  # GET /generated_contents/:id/edit
  def edit
    @content_types = GeneratedContent::CONTENT_TYPES
    @format_variants = GeneratedContent::FORMAT_VARIANTS
  end

  # PATCH/PUT /generated_contents/:id
  def update
    # Create new version if content is significantly changed
    if content_significantly_changed?
      new_version = @generated_content.create_new_version!(
        Current.user,
        params[:change_summary] || 'Content updated'
      )
      
      if new_version.update(content_params)
        redirect_to new_version, notice: 'Content was updated and new version created.'
      else
        @content_types = GeneratedContent::CONTENT_TYPES
        @format_variants = GeneratedContent::FORMAT_VARIANTS
        @generated_content = new_version
        render :edit, status: :unprocessable_entity
      end
    else
      # Minor update - update in place
      if @generated_content.update(content_params)
        redirect_to @generated_content, notice: 'Content was successfully updated.'
      else
        @content_types = GeneratedContent::CONTENT_TYPES
        @format_variants = GeneratedContent::FORMAT_VARIANTS
        render :edit, status: :unprocessable_entity
      end
    end
  end

  # DELETE /generated_contents/:id
  def destroy
    campaign_plan = @generated_content.campaign_plan
    @generated_content.soft_delete!
    
    redirect_to [campaign_plan, :generated_contents], notice: 'Content was successfully deleted.'
  end

  # POST /campaign_plans/:campaign_plan_id/generated_contents/generate
  def generate
    result = ContentGenerationService.generate_content(
      @campaign_plan,
      generation_params[:content_type],
      generation_params.except(:content_type)
    )
    
    respond_to do |format|
      if result[:success]
        @generated_content = result[:data][:content]
        
        format.html do
          redirect_to [@campaign_plan, @generated_content], 
                     notice: 'Content generated successfully!'
        end
        format.json { render json: content_detail_json(@generated_content), status: :created }
      else
        format.html do
          redirect_to [@campaign_plan, :generated_contents], 
                     alert: "Content generation failed: #{result[:error]}"
        end
        format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  # POST /generated_contents/:id/regenerate
  def regenerate
    result = ContentGenerationService.regenerate_content(
      @generated_content.id,
      regeneration_params
    )
    
    respond_to do |format|
      if result[:success]
        new_content = result[:data][:content]
        
        format.html do
          redirect_to new_content, 
                     notice: "Content regenerated as version #{new_content.version_number}!"
        end
        format.json { render json: content_detail_json(new_content), status: :ok }
      else
        format.html do
          redirect_to @generated_content, 
                     alert: "Regeneration failed: #{result[:error]}"
        end
        format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /generated_contents/:id/approve
  def approve
    result = ContentGenerationService.approve_content(@generated_content.id, Current.user)
    
    respond_to do |format|
      if result[:success]
        format.html do
          redirect_to @generated_content, notice: 'Content approved successfully!'
        end
        format.json { render json: content_detail_json(@generated_content.reload), status: :ok }
      else
        format.html do
          redirect_to @generated_content, alert: "Approval failed: #{result[:error]}"
        end
        format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /generated_contents/:id/publish
  def publish
    if @generated_content.publish!(Current.user)
      respond_to do |format|
        format.html do
          redirect_to @generated_content, notice: 'Content published successfully!'
        end
        format.json { render json: content_detail_json(@generated_content), status: :ok }
      end
    else
      respond_to do |format|
        format.html do
          redirect_to @generated_content, 
                     alert: 'Content must be approved before publishing.'
        end
        format.json do
          render json: { 
            error: 'Content must be approved before publishing',
            errors: @generated_content.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH /generated_contents/:id/archive
  def archive
    @generated_content.archive!(Current.user)
    
    respond_to do |format|
      format.html do
        redirect_to [@generated_content.campaign_plan, :generated_contents], 
                   notice: 'Content archived successfully!'
      end
      format.json { render json: content_detail_json(@generated_content), status: :ok }
    end
  end

  # POST /generated_contents/:id/create_variants
  def create_variants
    variants = params[:variants] || []
    
    if variants.empty?
      return respond_with_error('No variants specified', :bad_request)
    end
    
    result = ContentGenerationService.create_format_variants(@generated_content.id, variants)
    
    respond_to do |format|
      if result[:success]
        format.html do
          redirect_to @generated_content, 
                     notice: "Created #{result[:data][:total_created]} new variants!"
        end
        format.json { render json: result[:data], status: :ok }
      else
        format.html do
          redirect_to @generated_content, 
                     alert: "Failed to create variants: #{result[:error]}"
        end
        format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  # GET /generated_contents/search
  def search
    query = params[:q]
    
    if query.blank?
      @generated_contents = GeneratedContent.none
    else
      @generated_contents = content_scope
        .search_content(query)
        .includes(:campaign_plan, :created_by)
        .recent
    end
    
    # Simple pagination fallback for search results
    @generated_contents = @generated_contents.limit(20)
    
    respond_to do |format|
      format.html { render :index }
      format.json { render json: content_json_response(@generated_contents) }
    end
  end

  private

  def set_generated_content
    @generated_content = GeneratedContent.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to generated_contents_path, alert: 'Content not found.' }
      format.json { render json: { error: 'Content not found' }, status: :not_found }
    end
  end

  def set_campaign_plan
    @campaign_plan = if params[:campaign_plan_id]
                      CampaignPlan.find(params[:campaign_plan_id])
                    else
                      nil
                    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to campaign_plans_path, alert: 'Campaign plan not found.' }
      format.json { render json: { error: 'Campaign plan not found' }, status: :not_found }
    end
  end

  def authorize_content
    action_mapping = {
      'show' => :show?,
      'edit' => :edit?,
      'update' => :update?,
      'destroy' => :destroy?,
      'regenerate' => :regenerate?,
      'approve' => :approve?,
      'publish' => :publish?,
      'archive' => :archive?
    }
    
    policy_action = action_mapping[action_name] || :show?
    authorize @generated_content, policy_action
  rescue Pundit::NotAuthorizedError
    respond_to do |format|
      format.html { redirect_back_or_to(root_path, alert: 'Not authorized to access this content.') }
      format.json { render json: { error: 'Not authorized' }, status: :forbidden }
    end
  end

  def authorize_campaign_plan
    return unless @campaign_plan
    
    authorize @campaign_plan, :show?
  rescue Pundit::NotAuthorizedError
    respond_to do |format|
      format.html { redirect_back_or_to(root_path, alert: 'Not authorized to access this campaign.') }
      format.json { render json: { error: 'Not authorized' }, status: :forbidden }
    end
  end

  def content_scope
    if @campaign_plan
      policy_scope(@campaign_plan.generated_contents)
    else
      policy_scope(GeneratedContent)
    end
  end

  def apply_filters(contents)
    contents = contents.by_content_type(params[:content_type]) if params[:content_type].present?
    contents = contents.by_status(params[:status]) if params[:status].present?
    contents = contents.by_format_variant(params[:format_variant]) if params[:format_variant].present?
    contents = contents.by_creator(params[:creator_id]) if params[:creator_id].present?
    
    # Search by title or content
    if params[:search].present?
      contents = contents.search_content(params[:search])
    end
    
    contents
  end

  def content_params
    params.require(:generated_content).permit(
      :title, :body_content, :content_type, :format_variant, :metadata
    )
  end

  def generation_params
    params.require(:generation).permit(
      :content_type, :format_variant, :title, :tone, :platform, :email_type,
      :ad_type, :page_type, :generate_variants, :enable_fallback,
      custom_prompts: {}, key_features: []
    )
  end

  def regeneration_params
    params.permit(:change_summary, :preserve_approval)
  end

  def content_significantly_changed?
    return false unless content_params[:body_content]
    
    # Consider it significant if body content changes by more than 20%
    original_length = @generated_content.body_content.length
    new_length = content_params[:body_content].length
    
    return true if original_length.zero?
    
    change_percentage = ((new_length - original_length).abs.to_f / original_length) * 100
    change_percentage > 20
  end

  def set_campaign_context(content)
    # Pre-populate with campaign information
    content.metadata = {
      campaign_context: {
        campaign_name: @campaign_plan.name,
        campaign_type: @campaign_plan.campaign_type,
        objective: @campaign_plan.objective,
        target_audience: @campaign_plan.target_audience_summary
      }
    }
  end

  def content_analytics(content)
    {
      word_count: content.word_count,
      character_count: content.character_count,
      estimated_read_time: content.estimated_read_time,
      version_count: content.original_version? ? content.content_versions.count + 1 : 0,
      created_days_ago: content.created_at ? ((Time.current - content.created_at) / 1.day).round(1) : 0,
      last_updated: content.updated_at,
      approval_status: content.status,
      platform_optimized: content.metadata.dig('platform_settings')&.keys || []
    }
  end

  def content_json_response(contents)
    {
      contents: contents.map do |content|
        {
          id: content.id,
          title: content.title,
          content_type: content.content_type,
          format_variant: content.format_variant,
          status: content.status,
          version_number: content.version_number,
          word_count: content.word_count,
          creator: content.created_by.full_name,
          created_at: content.created_at,
          updated_at: content.updated_at,
          campaign_name: content.campaign_plan.name,
          is_latest_version: content.latest_version?,
          url: generated_content_path(content)
        }
      end,
      pagination: {
        current_page: 1,
        total_pages: 1,
        total_count: contents.count,
        per_page: 20
      },
      filters: {
        content_types: GeneratedContent::CONTENT_TYPES,
        format_variants: GeneratedContent::FORMAT_VARIANTS,
        statuses: GeneratedContent::STATUSES
      }
    }
  end

  def content_detail_json(content)
    {
      id: content.id,
      title: content.title,
      body_content: content.body_content,
      content_type: content.content_type,
      format_variant: content.format_variant,
      status: content.status,
      version_number: content.version_number,
      metadata: content.metadata,
      creator: {
        id: content.created_by.id,
        name: content.created_by.full_name
      },
      approver: content.approver ? {
        id: content.approver.id,
        name: content.approver.full_name
      } : nil,
      campaign: {
        id: content.campaign_plan.id,
        name: content.campaign_plan.name
      },
      analytics: content_analytics(content),
      version_history: content.version_history_chain.map do |version|
        {
          id: version.id,
          version_number: version.version_number,
          created_at: version.created_at,
          creator: version.created_by.full_name,
          change_summary: version.metadata&.dig('change_summary')
        }
      end,
      created_at: content.created_at,
      updated_at: content.updated_at,
      urls: {
        self: generated_content_path(content),
        edit: edit_generated_content_path(content),
        regenerate: regenerate_generated_content_path(content),
        approve: approve_generated_content_path(content),
        publish: publish_generated_content_path(content),
        archive: archive_generated_content_path(content)
      }
    }
  end

  def respond_with_error(message, status = :unprocessable_entity)
    respond_to do |format|
      format.html { redirect_back_or_to(root_path, alert: message) }
      format.json { render json: { error: message }, status: status }
    end
  end
end