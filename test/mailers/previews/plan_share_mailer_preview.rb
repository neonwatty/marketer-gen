# Preview all emails at http://localhost:3000/rails/mailers/plan_share_mailer
class PlanShareMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/plan_share_mailer/share_plan
  def share_plan
    PlanShareMailer.share_plan
  end
end
