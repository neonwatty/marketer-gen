# frozen_string_literal: true

# Mailer for sending campaign execution notifications
class CampaignExecutionMailer < ApplicationMailer
  default from: 'campaigns@marketergen.com'
  
  # Send notification when execution completes successfully
  def execution_completed(email, user, execution_schedule, execution_result = {})
    @user = user
    @execution_schedule = execution_schedule
    @campaign_plan = execution_schedule.campaign_plan
    @execution_result = execution_result
    @platforms = execution_schedule.target_platforms
    @duration = execution_schedule.execution_duration
    @schedule_url = execution_schedule_url(execution_schedule)
    
    mail(
      to: email,
      subject: "✅ Campaign Execution Completed: #{@execution_schedule.name}"
    )
  end
  
  # Send notification when execution fails
  def execution_failed(email, user, execution_schedule, error_message = nil)
    @user = user
    @execution_schedule = execution_schedule
    @campaign_plan = execution_schedule.campaign_plan
    @error_message = error_message
    @platforms = execution_schedule.target_platforms
    @retry_count = execution_schedule.retry_count
    @can_retry = execution_schedule.can_be_retried?
    @schedule_url = execution_schedule_url(execution_schedule)
    
    mail(
      to: email,
      subject: "❌ Campaign Execution Failed: #{@execution_schedule.name}"
    )
  end
  
  # Send notification when rollback completes successfully
  def rollback_completed(email, user, execution_schedule, rollback_result = {})
    @user = user
    @execution_schedule = execution_schedule
    @campaign_plan = execution_schedule.campaign_plan
    @rollback_result = rollback_result
    @platforms = execution_schedule.target_platforms
    @schedule_url = execution_schedule_url(execution_schedule)
    
    mail(
      to: email,
      subject: "🔄 Campaign Rollback Completed: #{@execution_schedule.name}"
    )
  end
  
  # Send notification when rollback fails
  def rollback_failed(email, user, execution_schedule, error_message = nil)
    @user = user
    @execution_schedule = execution_schedule
    @campaign_plan = execution_schedule.campaign_plan
    @error_message = error_message
    @platforms = execution_schedule.target_platforms
    @schedule_url = execution_schedule_url(execution_schedule)
    
    mail(
      to: email,
      subject: "⚠️ Campaign Rollback Failed: #{@execution_schedule.name}"
    )
  end
  
  private
  
  def execution_schedule_url(execution_schedule)
    # This would be the actual URL in your application
    # For now, return a placeholder
    "#{Rails.application.config.host}/execution_schedules/#{execution_schedule.id}"
  end
end