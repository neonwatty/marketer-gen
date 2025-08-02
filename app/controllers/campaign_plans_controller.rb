class CampaignPlansController < ApplicationController
  before_action :set_campaign_plan, only: [:show, :edit, :update, :destroy, :approve, :reject, :submit_for_review, :export]
  before_action :set_campaign, only: [:index, :new, :create]

  # GET /campaigns/:campaign_id/plans
  def index
    @plans = @campaign.campaign_plans.includes(:user, :plan_revisions, :plan_comments)
                     .latest_version.order(updated_at: :desc)
    @draft_plans = @plans.draft
    @review_plans = @plans.in_review
    @approved_plans = @plans.approved
  end

  # GET /campaign_plans/:id
  def show
    @comments = @campaign_plan.plan_comments.includes(:user).order(created_at: :desc)
    @revisions = @campaign_plan.plan_revisions.includes(:user).order(created_at: :desc)
    @can_approve = can_approve_plan?(@campaign_plan)
    @can_edit = can_edit_plan?(@campaign_plan)
  end

  # GET /campaigns/:campaign_id/plans/new
  def new
    @campaign_plan = @campaign.campaign_plans.build
    @templates = available_templates
    @industry_types = PlanTemplate::INDUSTRY_TYPES
    @plan_types = CampaignPlan::PLAN_TYPES
  end

  # GET /campaign_plans/:id/edit
  def edit
    return redirect_to @campaign_plan, alert: 'Cannot edit approved plans' if @campaign_plan.approved?
    
    @templates = available_templates
    @industry_types = PlanTemplate::INDUSTRY_TYPES
    @plan_types = CampaignPlan::PLAN_TYPES
  end

  # POST /campaigns/:campaign_id/plans
  def create
    @campaign_plan = @campaign.campaign_plans.build(campaign_plan_params)
    @campaign_plan.user = current_user

    # Apply template if selected
    if params[:template_id].present?
      template = PlanTemplate.find(params[:template_id])
      apply_template_to_plan(@campaign_plan, template)
    end

    if @campaign_plan.save
      redirect_to @campaign_plan, notice: 'Campaign plan was successfully created.'
    else
      @templates = available_templates
      @industry_types = PlanTemplate::INDUSTRY_TYPES
      @plan_types = CampaignPlan::PLAN_TYPES
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /campaign_plans/:id
  def update
    if @campaign_plan.update(campaign_plan_params)
      redirect_to @campaign_plan, notice: 'Campaign plan was successfully updated.'
    else
      @templates = available_templates
      @industry_types = PlanTemplate::INDUSTRY_TYPES
      @plan_types = CampaignPlan::PLAN_TYPES
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /campaign_plans/:id
  def destroy
    campaign = @campaign_plan.campaign
    @campaign_plan.destroy!
    redirect_to campaign_campaign_plans_path(campaign), notice: 'Campaign plan was successfully deleted.'
  end

  # POST /campaign_plans/:id/submit_for_review
  def submit_for_review
    @campaign_plan.submit_for_review!
    CampaignApprovalNotificationSystem.new.notify_stakeholders(@campaign_plan)
    redirect_to @campaign_plan, notice: 'Plan submitted for review successfully.'
  end

  # POST /campaign_plans/:id/approve
  def approve
    return redirect_to @campaign_plan, alert: 'Unauthorized to approve plans' unless can_approve_plan?(@campaign_plan)
    
    @campaign_plan.approve!
    CampaignApprovalNotificationSystem.new.notify_approval(@campaign_plan)
    redirect_to @campaign_plan, notice: 'Plan approved successfully.'
  end

  # POST /campaign_plans/:id/reject
  def reject
    return redirect_to @campaign_plan, alert: 'Unauthorized to reject plans' unless can_approve_plan?(@campaign_plan)
    
    reason = params[:rejection_reason] || 'No reason provided'
    @campaign_plan.reject!(reason)
    CampaignApprovalNotificationSystem.new.notify_rejection(@campaign_plan, reason)
    redirect_to @campaign_plan, notice: 'Plan rejected with feedback.'
  end

  # GET /campaign_plans/:id/export
  def export
    format = params[:format] || 'pdf'
    exporter = CampaignPlanExporter.new(@campaign_plan)
    
    case format
    when 'pdf'
      send_data exporter.generate_pdf, 
                filename: "#{@campaign_plan.name.parameterize}-v#{@campaign_plan.version}.pdf",
                type: 'application/pdf'
    when 'pptx'
      send_data exporter.generate_powerpoint,
                filename: "#{@campaign_plan.name.parameterize}-v#{@campaign_plan.version}.pptx",
                type: 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
    else
      redirect_to @campaign_plan, alert: 'Unsupported export format'
    end
  end

  # GET /campaign_plans/:id/dashboard
  def dashboard
    @timeline_data = prepare_timeline_data(@campaign_plan)
    @channel_data = prepare_channel_data(@campaign_plan)
    @budget_data = prepare_budget_data(@campaign_plan)
    @metrics_data = prepare_metrics_data(@campaign_plan)
    @collaboration_data = prepare_collaboration_data(@campaign_plan)
  end

  private

  def set_campaign_plan
    @campaign_plan = CampaignPlan.find(params[:id])
  end

  def set_campaign
    @campaign = current_user.campaigns.find(params[:campaign_id])
  end

  def campaign_plan_params
    params.require(:campaign_plan).permit(
      :name, :plan_type, :status,
      strategic_rationale: {},
      target_audience: {},
      messaging_framework: {},
      channel_strategy: [],
      timeline_phases: [],
      success_metrics: {},
      budget_allocation: {},
      creative_approach: {},
      market_analysis: {},
      metadata: {}
    )
  end

  def available_templates
    PlanTemplate.active
                .where(
                  "is_public = ? OR user_id = ?", 
                  true, current_user.id
                )
                .order(:industry_type, :name)
  end

  def apply_template_to_plan(plan, template)
    template_data = template.apply_to_campaign(plan.campaign)
    
    plan.strategic_rationale = template_data['strategic_rationale']
    plan.target_audience = template_data['target_audience']
    plan.messaging_framework = template_data['messaging_framework']
    plan.channel_strategy = template_data['channel_strategy']
    plan.timeline_phases = template_data['timeline_phases']
    plan.success_metrics = template_data['success_metrics']
    plan.budget_allocation = template_data['budget_allocation'] if template_data['budget_allocation']
    plan.creative_approach = template_data['creative_approach'] if template_data['creative_approach']
    plan.market_analysis = template_data['market_analysis'] if template_data['market_analysis']
  end

  def can_approve_plan?(plan)
    current_user.admin? || current_user == plan.campaign.user
  end

  def can_edit_plan?(plan)
    return false if plan.approved?
    current_user == plan.user || current_user.admin?
  end

  def prepare_timeline_data(plan)
    return {} unless plan.timeline_phases.present?
    
    phases = plan.timeline_phases.map.with_index do |phase, index|
      {
        id: "phase_#{index}",
        name: phase['phase'],
        duration_weeks: phase['duration_weeks'],
        activities: phase['activities'] || [],
        start_week: index == 0 ? 0 : plan.timeline_phases[0...index].sum { |p| p['duration_weeks'] || 0 },
        phase_type: phase['phase_type'] || 'standard',
        color: phase_color(phase['phase'])
      }
    end
    
    {
      phases: phases,
      total_weeks: phases.sum { |p| p[:duration_weeks] || 0 },
      critical_path: identify_critical_path(phases)
    }
  end

  def prepare_channel_data(plan)
    return {} unless plan.channel_strategy.present?
    
    plan.channel_strategy.map do |channel|
      {
        name: channel.humanize,
        slug: channel,
        budget_allocation: plan.budget_allocation&.dig(channel) || 0,
        expected_reach: estimate_channel_reach(channel, plan),
        primary_kpis: channel_kpis(channel)
      }
    end
  end

  def prepare_budget_data(plan)
    return {} unless plan.budget_allocation.present?
    
    {
      total_budget: plan.total_budget,
      channel_allocation: plan.budget_allocation,
      phase_allocation: calculate_phase_budgets(plan),
      recommended_reserves: plan.total_budget * 0.1
    }
  end

  def prepare_metrics_data(plan)
    return {} unless plan.success_metrics.present?
    
    {
      awareness_metrics: plan.success_metrics['awareness'] || {},
      consideration_metrics: plan.success_metrics['consideration'] || {},
      conversion_metrics: plan.success_metrics['conversion'] || {},
      retention_metrics: plan.success_metrics['retention'] || {}
    }
  end

  def prepare_collaboration_data(plan)
    {
      stakeholders: identify_stakeholders(plan),
      pending_approvals: plan.in_review? ? [current_user] : [],
      recent_comments: plan.plan_comments.recent.includes(:user).limit(5),
      approval_workflow: CampaignApprovalWorkflow.new(plan).status
    }
  end

  def phase_color(phase_name)
    case phase_name.to_s.downcase
    when 'awareness', 'pre_launch', 'pre_event'
      'journey-awareness'
    when 'consideration', 'launch', 'during_event'
      'journey-consideration'
    when 'conversion', 'decision', 'post_event'
      'journey-conversion'
    when 'retention', 'growth', 'post_launch'
      'journey-retention'
    else
      'journey-awareness'
    end
  end

  def identify_critical_path(phases)
    # Simple critical path identification based on dependencies
    phases.select { |phase| phase[:duration_weeks] && phase[:duration_weeks] > 4 }
  end

  def estimate_channel_reach(channel, plan)
    # Placeholder for channel reach estimation logic
    case channel
    when 'social_media' then plan.total_budget * 100
    when 'email' then plan.total_budget * 50
    when 'paid_search' then plan.total_budget * 75
    else plan.total_budget * 25
    end
  end

  def channel_kpis(channel)
    case channel
    when 'social_media'
      ['Impressions', 'Engagement Rate', 'Reach']
    when 'email'
      ['Open Rate', 'Click Rate', 'Conversions']
    when 'paid_search'
      ['Click-through Rate', 'Cost per Click', 'Conversions']
    when 'content_marketing'
      ['Page Views', 'Time on Page', 'Lead Generation']
    else
      ['Reach', 'Engagement', 'Conversions']
    end
  end

  def calculate_phase_budgets(plan)
    return {} unless plan.timeline_phases.present? && plan.budget_allocation.present?
    
    total_weeks = plan.timeline_phases.sum { |p| p['duration_weeks'] || 0 }
    
    plan.timeline_phases.map.with_index do |phase, index|
      phase_weeks = phase['duration_weeks'] || 0
      budget_percentage = total_weeks > 0 ? (phase_weeks.to_f / total_weeks) : 0
      
      {
        phase: phase['phase'],
        budget: (plan.total_budget * budget_percentage).round,
        percentage: (budget_percentage * 100).round(1)
      }
    end
  end

  def identify_stakeholders(plan)
    stakeholders = [plan.user, plan.campaign.user].uniq
    stakeholders += User.where(admin: true) if plan.in_review?
    stakeholders.map { |user| { id: user.id, name: user.display_name, role: user_role_for_plan(user, plan) } }
  end

  def user_role_for_plan(user, plan)
    return 'Plan Owner' if user == plan.user
    return 'Campaign Owner' if user == plan.campaign.user
    return 'Admin' if user.admin?
    'Stakeholder'
  end
end