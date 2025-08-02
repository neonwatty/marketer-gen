class CampaignsController < ApplicationController
  before_action :set_campaign, only: [:show]

  # GET /campaigns
  def index
    @campaigns = current_user.campaigns.includes(:persona, :journeys)
                             .order(updated_at: :desc)
    
    # Apply filters if present
    @campaigns = @campaigns.where(status: params[:status]) if params[:status].present?
    @campaigns = @campaigns.where(campaign_type: params[:type]) if params[:type].present?
    
    # Apply search
    if params[:search].present?
      @campaigns = @campaigns.where(
        'name ILIKE ? OR description ILIKE ?',
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end
    
    @campaigns = @campaigns.page(params[:page]).per(12)
  end

  # GET /campaigns/:id
  def show
    @campaign_plans = @campaign.campaign_plans.includes(:plan_comments)
    @journeys = @campaign.journeys.includes(:journey_steps)
    @recent_analytics = @campaign.performance_summary
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
end