class CampaignsController < ApplicationController
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :duplicate, :archive, :workflow, :status_history, :check_milestones, :execute_rule]
  before_action :set_campaigns_for_bulk, only: [:bulk_update, :bulk_delete, :bulk_export]

  # GET /campaigns
  def index
    @campaigns = current_user.campaigns.includes(:persona, :journeys, :campaign_plans, :ab_tests)
    
    # Apply sorting
    sort_column = params[:sort] || 'updated_at'
    sort_direction = params[:direction] || 'desc'
    
    case sort_column
    when 'name'
      @campaigns = @campaigns.order("name #{sort_direction}")
    when 'status'
      @campaigns = @campaigns.order("status #{sort_direction}")
    when 'campaign_type'
      @campaigns = @campaigns.order("campaign_type #{sort_direction}")
    when 'created_at'
      @campaigns = @campaigns.order("created_at #{sort_direction}")
    when 'performance'
      # Custom ordering by performance metrics
      @campaigns = @campaigns.left_joins(:journey_analytics)
                             .group('campaigns.id')
                             .order("AVG(journey_analytics.completion_rate) #{sort_direction} NULLS LAST")
    else
      @campaigns = @campaigns.order("updated_at #{sort_direction}")
    end
    
    # Apply filters
    @campaigns = @campaigns.where(status: params[:status]) if params[:status].present?
    @campaigns = @campaigns.where(campaign_type: params[:type]) if params[:type].present?
    @campaigns = @campaigns.where(persona_id: params[:persona_id]) if params[:persona_id].present?
    
    # Date range filter
    if params[:date_from].present?
      @campaigns = @campaigns.where('created_at >= ?', Date.parse(params[:date_from]))
    end
    if params[:date_to].present?
      @campaigns = @campaigns.where('created_at <= ?', Date.parse(params[:date_to]))
    end
    
    # Apply search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @campaigns = @campaigns.joins(:persona)
                             .where(
                               'campaigns.name ILIKE ? OR campaigns.description ILIKE ? OR personas.name ILIKE ?',
                               search_term, search_term, search_term
                             )
    end
    
    # Pagination
    @campaigns = @campaigns.page(params[:page]).per(params[:per_page] || 25)
    
    # View mode (table or grid)
    @view_mode = params[:view] || 'table'
    
    # Export handling
    respond_to do |format|
      format.html
      format.json { render json: campaign_table_data }
      format.csv { send_data generate_csv_export, filename: "campaigns_#{Date.current}.csv" }
      format.xlsx { send_data generate_xlsx_export, filename: "campaigns_#{Date.current}.xlsx" }
    end
  end

  # GET /campaigns/:id
  def show
    @campaign_plans = @campaign.campaign_plans.includes(:plan_comments)
    @journeys = @campaign.journeys.includes(:journey_steps)
    @recent_analytics = @campaign.performance_summary
  end

  # GET /campaigns/new
  def new
    @campaign = current_user.campaigns.build
    @personas = current_user.personas.active
    @step = params[:step] || '1'
  end

  # POST /campaigns
  def create
    @campaign = current_user.campaigns.build(campaign_params)
    
    if @campaign.save
      respond_to do |format|
        format.html { redirect_to @campaign, notice: 'Campaign created successfully.' }
        format.json { render json: @campaign, status: :created }
      end
    else
      @personas = current_user.personas.active
      @step = params[:step] || '1'
      respond_to do |format|
        format.html { render :new }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /campaigns/:id/edit
  def edit
    @personas = current_user.personas.active
    @step = params[:step] || '1'
  end

  # PATCH/PUT /campaigns/:id
  def update
    if @campaign.update(campaign_params)
      respond_to do |format|
        format.html { redirect_to @campaign, notice: 'Campaign updated successfully.' }
        format.json { render json: @campaign }
      end
    else
      @personas = current_user.personas.active
      @step = params[:step] || '1'
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /campaigns/:id
  def destroy
    @campaign.destroy
    respond_to do |format|
      format.html { redirect_to campaigns_path, notice: 'Campaign deleted successfully.' }
      format.json { head :no_content }
    end
  end

  # POST /campaigns/:id/duplicate
  def duplicate
    new_campaign = @campaign.dup
    new_campaign.name = "#{@campaign.name} (Copy)"
    new_campaign.status = 'draft'
    new_campaign.started_at = nil
    new_campaign.ended_at = nil
    
    if new_campaign.save
      redirect_to edit_campaign_path(new_campaign), notice: 'Campaign duplicated successfully.'
    else
      redirect_to @campaign, alert: 'Failed to duplicate campaign.'
    end
  end

  # PATCH /campaigns/:id/archive
  def archive
    @campaign.archive!
    respond_to do |format|
      format.html { redirect_to campaigns_path, notice: 'Campaign archived successfully.' }
      format.json { render json: @campaign }
    end
  end

  # PATCH /campaigns/bulk_update
  def bulk_update
    success_count = 0
    @campaigns.each do |campaign|
      if campaign.update(bulk_update_params)
        success_count += 1
      end
    end
    
    respond_to do |format|
      format.html { redirect_to campaigns_path, notice: "#{success_count} campaigns updated successfully." }
      format.json { render json: { success: true, updated_count: success_count } }
    end
  end

  # DELETE /campaigns/bulk_delete
  def bulk_delete
    deleted_count = @campaigns.destroy_all.count
    
    respond_to do |format|
      format.html { redirect_to campaigns_path, notice: "#{deleted_count} campaigns deleted successfully." }
      format.json { render json: { success: true, deleted_count: deleted_count } }
    end
  end

  # GET /campaigns/bulk_export
  def bulk_export
    respond_to do |format|
      format.csv { send_data generate_bulk_csv_export, filename: "selected_campaigns_#{Date.current}.csv" }
      format.xlsx { send_data generate_bulk_xlsx_export, filename: "selected_campaigns_#{Date.current}.xlsx" }
    end
  end

  # GET /campaigns/intake
  def intake
    # Check if user has any active intake sessions
    @active_session = current_user.campaign_intake_sessions.active.recent.first
    
    # Set page metadata
    @page_title = "Campaign Assistant"
    @page_description = "Create your marketing campaign with our conversational AI assistant"
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to campaigns_path, alert: 'Campaign not found.'
  end

  def set_campaigns_for_bulk
    campaign_ids = params[:campaign_ids] || params[:ids]
    @campaigns = current_user.campaigns.where(id: campaign_ids)
  end

  def campaign_params
    params.require(:campaign).permit(
      :name, :description, :campaign_type, :status, :persona_id,
      :target_audience, :budget, :start_date, :end_date,
      :primary_goal, :secondary_goals, :success_metrics,
      :channels, :messaging_tone, :brand_guidelines,
      :compliance_requirements, :approval_workflow,
      metadata: {}
    )
  end

  def bulk_update_params
    params.permit(:status, :campaign_type, :persona_id)
  end

  def campaign_table_data
    {
      campaigns: @campaigns.map do |campaign|
        {
          id: campaign.id,
          name: campaign.name,
          status: campaign.status,
          type: campaign.campaign_type,
          persona: campaign.persona.name,
          created_at: campaign.created_at.strftime('%m/%d/%Y'),
          updated_at: campaign.updated_at.strftime('%m/%d/%Y'),
          performance: campaign.performance_summary,
          journeys_count: campaign.journeys.count,
          actions: render_to_string(partial: 'campaigns/table_actions', locals: { campaign: campaign })
        }
      end,
      pagination: {
        current_page: @campaigns.current_page,
        total_pages: @campaigns.total_pages,
        total_count: @campaigns.total_count,
        per_page: @campaigns.limit_value
      }
    }
  end

  def generate_csv_export
    CSV.generate(headers: true) do |csv|
      csv << campaign_csv_headers
      @campaigns.each do |campaign|
        csv << campaign_csv_row(campaign)
      end
    end
  end

  def generate_xlsx_export
    # Implementation for XLSX export would go here
    # For now, return CSV data
    generate_csv_export
  end

  def generate_bulk_csv_export
    CSV.generate(headers: true) do |csv|
      csv << campaign_csv_headers
      @campaigns.each do |campaign|
        csv << campaign_csv_row(campaign)
      end
    end
  end

  def generate_bulk_xlsx_export
    # Implementation for bulk XLSX export would go here
    generate_bulk_csv_export
  end

  def campaign_csv_headers
    [
      'ID', 'Name', 'Description', 'Status', 'Type', 'Persona',
      'Created At', 'Updated At', 'Started At', 'Ended At',
      'Journeys Count', 'Completion Rate', 'Conversion Rate'
    ]
  end

  def campaign_csv_row(campaign)
    performance = campaign.performance_summary
    [
      campaign.id,
      campaign.name,
      campaign.description,
      campaign.status,
      campaign.campaign_type,
      campaign.persona.name,
      campaign.created_at,
      campaign.updated_at,
      campaign.started_at,
      campaign.ended_at,
      campaign.journeys.count,
      performance[:completion_rate] || 0,
      performance[:conversion_rate] || 0
    ]
  end

  # GET /campaigns/:id/workflow
  def workflow
    respond_to do |format|
      format.html { render partial: 'workflow_visualization', locals: { campaign: @campaign } }
      format.json { render json: workflow_data }
    end
  end

  # GET /campaigns/:id/workflow/data
  def workflow_data
    {
      nodes: {
        start: { current: false, completed: true },
        draft: { current: @campaign.status == 'draft', completed: status_reached?(@campaign.status, 'draft') },
        active: { current: @campaign.status == 'active', completed: status_reached?(@campaign.status, 'active') },
        paused: { current: @campaign.status == 'paused', completed: status_reached?(@campaign.status, 'paused') },
        completed: { current: @campaign.status == 'completed', completed: status_reached?(@campaign.status, 'completed') },
        archived: { current: @campaign.status == 'archived', completed: status_reached?(@campaign.status, 'archived') }
      },
      stats: {
        completedSteps: get_completed_steps_count(@campaign),
        pendingSteps: get_pending_steps_count(@campaign),
        progress: get_workflow_progress(@campaign),
        estimatedCompletion: get_estimated_completion(@campaign)
      }
    }
  end

  # GET /campaigns/:id/workflow/node/:node_id
  def workflow_node
    node_id = params[:node_id]
    render partial: 'workflow_node_details', locals: { campaign: @campaign, node_id: node_id }
  end

  # GET /campaigns/:id/status_history
  def status_history
    render partial: 'status_history', locals: { campaign: @campaign }
  end

  # GET /campaigns/:id/check_milestones
  def check_milestones
    milestones = check_campaign_milestones(@campaign)
    render json: milestones
  end

  # POST /campaigns/:id/execute_rule
  def execute_rule
    rule_id = params[:rule_id]
    result = execute_automated_rule(@campaign, rule_id)
    render json: result
  end

  # GET /campaigns/:id/automated_rules
  def automated_rules
    rules = get_automated_rules(@campaign)
    render json: rules
  end

  # GET /campaigns/:id/quick_actions
  def quick_actions
    status = params[:status] || @campaign.status
    render partial: 'status_quick_actions', locals: { campaign: @campaign.tap { |c| c.status = status } }
  end

  # GET /campaigns/:id/status
  def campaign_status
    render json: { status: @campaign.status, updated_at: @campaign.updated_at }
  end

  private

  # Helper method to check if a status has been reached
  def status_reached?(current_status, target_status)
    status_order = ['draft', 'active', 'paused', 'completed', 'archived']
    current_index = status_order.index(current_status) || 0
    target_index = status_order.index(target_status) || 0
    
    # Special case for paused - it's not "reached" in linear progression
    return current_status == 'paused' if target_status == 'paused'
    
    current_index >= target_index
  end

  # Helper method to check campaign milestones
  def check_campaign_milestones(campaign)
    milestones = []
    
    # Example milestones - in a real app these would be configurable
    if campaign.status == 'active'
      # Check budget milestone
      if campaign.budget_spent_percentage && campaign.budget_spent_percentage >= 80
        milestones << {
          id: 'budget_80',
          name: '80% Budget Spent',
          triggered: true,
          automated_action: 'notify_manager'
        }
      end
      
      # Check performance milestone
      performance = campaign.performance_summary
      if performance[:completion_rate] && performance[:completion_rate] >= 90
        milestones << {
          id: 'completion_90',
          name: '90% Completion Rate',
          triggered: true,
          automated_action: 'consider_completion'
        }
      end
    end
    
    milestones
  end

  # Helper method to execute automated rules
  def execute_automated_rule(campaign, rule_id)
    # This would execute the specified automated rule
    # For now, return a mock response
    {
      success: true,
      message: "Automated rule #{rule_id} executed successfully"
    }
  rescue => e
    {
      success: false,
      error: e.message
    }
  end
end