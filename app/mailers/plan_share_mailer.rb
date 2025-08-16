class PlanShareMailer < ApplicationMailer
  def share_plan(share_token, sender)
    @share_token = share_token
    @campaign_plan = share_token.campaign_plan
    @sender = sender
    @access_url = shared_plan_url(token: share_token.token)
    @expires_at = share_token.expires_at

    mail(
      to: share_token.email,
      subject: "#{@sender.full_name} shared a campaign plan with you: #{@campaign_plan.name}"
    )
  end

  private

  def shared_plan_url(token:)
    Rails.application.routes.url_helpers.shared_campaign_plan_url(token: token, host: default_url_options[:host])
  end
end
