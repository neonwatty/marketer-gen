class CampaignPlansController < ApplicationController
  include Authentication
  
  before_action :require_authentication
  before_action :set_campaign_plan, only: [:show, :edit, :update, :destroy, :generate, :regenerate, :archive, :export_pdf, :export_presentation, :share_plan]
  before_action :ensure_owner, only: [:show, :edit, :update, :destroy, :generate, :regenerate, :archive, :export_pdf, :export_presentation, :share_plan]
  
  def index
    @campaign_plans = Current.user.campaign_plans
      .includes(:user)
      .recent
    
    # Apply filters if provided
    @campaign_plans = @campaign_plans.by_campaign_type(params[:campaign_type]) if params[:campaign_type].present?
    @campaign_plans = @campaign_plans.by_objective(params[:objective]) if params[:objective].present?
    @campaign_plans = @campaign_plans.by_status(params[:status]) if params[:status].present?
    
    # Search by name if provided
    if params[:search].present?
      @campaign_plans = @campaign_plans.where("name LIKE ?", "%#{params[:search]}%")
    end
    
    @campaign_types = CampaignPlan::CAMPAIGN_TYPES
    @objectives = CampaignPlan::OBJECTIVES
    @statuses = CampaignPlan::STATUSES
  end
  
  def show
    @analytics = @campaign_plan.plan_analytics
  end
  
  def new
    @campaign_plan = Current.user.campaign_plans.build
    @campaign_types = CampaignPlan::CAMPAIGN_TYPES
    @objectives = CampaignPlan::OBJECTIVES
    
    set_brand_context(@campaign_plan)
  end
  
  def create
    @campaign_plan = Current.user.campaign_plans.build(campaign_plan_params)
    set_brand_context(@campaign_plan)
    
    if @campaign_plan.save
      redirect_to @campaign_plan, notice: 'Campaign plan was successfully created.'
    else
      @campaign_types = CampaignPlan::CAMPAIGN_TYPES
      @objectives = CampaignPlan::OBJECTIVES
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @campaign_types = CampaignPlan::CAMPAIGN_TYPES
    @objectives = CampaignPlan::OBJECTIVES
  end
  
  def update
    if @campaign_plan.update(campaign_plan_params)
      redirect_to @campaign_plan, notice: 'Campaign plan was successfully updated.'
    else
      @campaign_types = CampaignPlan::CAMPAIGN_TYPES
      @objectives = CampaignPlan::OBJECTIVES
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    campaign_plan_id = @campaign_plan.id
    @campaign_plan.destroy!
    
    redirect_to campaign_plans_path, notice: 'Campaign plan was successfully deleted.'
  end
  
  def generate
    return redirect_to @campaign_plan, alert: 'Campaign plan is not ready for generation.' unless @campaign_plan.ready_for_generation?
    
    service = CampaignPlanService.new(@campaign_plan)
    result = service.generate_plan
    
    if result[:success]
      redirect_to @campaign_plan, notice: 'Campaign plan is being generated. Please refresh to see updates.'
    else
      redirect_to @campaign_plan, alert: result[:message]
    end
  end
  
  def regenerate
    return redirect_to @campaign_plan, alert: 'Campaign plan cannot be regenerated.' unless @campaign_plan.can_be_regenerated?
    
    service = CampaignPlanService.new(@campaign_plan)
    result = service.regenerate_plan
    
    if result[:success]
      redirect_to @campaign_plan, notice: 'Campaign plan is being regenerated. Please refresh to see updates.'
    else
      redirect_to @campaign_plan, alert: result[:message]
    end
  end
  
  def archive
    if @campaign_plan.archive!
      redirect_to campaign_plans_path, notice: 'Campaign plan was successfully archived.'
    else
      redirect_to @campaign_plan, alert: 'Campaign plan cannot be archived.'
    end
  end

  def export_pdf
    unless @campaign_plan.completed?
      return redirect_to @campaign_plan, alert: 'Campaign plan must be completed before exporting.'
    end

    service = PlanPdfExportService.new(@campaign_plan)
    result = service.generate_pdf

    if result[:success]
      pdf = result[:pdf]
      filename = "#{@campaign_plan.name.parameterize}-campaign-plan.pdf"
      
      send_data pdf.render,
                filename: filename,
                type: 'application/pdf',
                disposition: 'attachment'
    else
      redirect_to @campaign_plan, alert: result[:message]
    end
  end

  def export_presentation
    unless @campaign_plan.completed?
      return redirect_to @campaign_plan, alert: 'Campaign plan must be completed before exporting.'
    end

    redirect_to @campaign_plan, alert: 'Presentation export is coming soon!'
  end

  def share_plan
    unless @campaign_plan.completed?
      return redirect_to @campaign_plan, alert: 'Campaign plan must be completed before sharing.'
    end

    email = params[:email]
    
    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to @campaign_plan, alert: 'Please provide a valid email address.'
    end

    begin
      share_token = @campaign_plan.plan_share_tokens.create!(email: email)
      PlanShareMailer.share_plan(share_token, Current.user).deliver_now
      
      redirect_to @campaign_plan, notice: "Campaign plan shared successfully with #{email}. Access expires in 7 days."
    rescue => e
      Rails.logger.error "Failed to share plan: #{e.message}"
      redirect_to @campaign_plan, alert: 'Failed to share campaign plan. Please try again.'
    end
  end
  
  private
  
  def set_campaign_plan
    @campaign_plan = Current.user.campaign_plans.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to campaign_plans_path, alert: 'Campaign plan not found.'
  end
  
  def ensure_owner
    return if @campaign_plan.user == Current.user
    
    redirect_to campaign_plans_path, alert: 'You can only access your own campaign plans.'
  end
  
  def set_brand_context(campaign_plan)
    # Pre-populate with user's active brand identity if available
    if Current.user.active_brand_identity
      brand = Current.user.active_brand_identity
      campaign_plan.brand_context = {
        brand_name: brand.name,
        brand_voice: brand.brand_voice,
        tone_guidelines: brand.tone_guidelines
      }.to_json
    end
  end
  
  def campaign_plan_params
    params.require(:campaign_plan).permit(
      :name, :description, :campaign_type, :objective,
      :target_audience, :brand_context, :budget_constraints, :timeline_constraints
    )
  end
end