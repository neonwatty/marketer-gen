class SharedCampaignPlansController < ApplicationController
  include Authentication
  
  # Allow unauthenticated access for shared plans
  allow_unauthenticated_access
  
  skip_before_action :verify_authenticity_token
  before_action :find_share_token
  before_action :verify_token_access

  def show
    @campaign_plan = @share_token.campaign_plan
    @share_token.access!
    @analytics = @campaign_plan.plan_analytics
  end

  private

  def find_share_token
    token = params[:token]
    @share_token = PlanShareToken.find_by(token: token)
    
    unless @share_token
      render 'errors/not_found', status: :not_found and return
    end
  end

  def verify_token_access
    unless @share_token.active?
      render 'errors/expired_link', status: :gone and return
    end
  end
end
