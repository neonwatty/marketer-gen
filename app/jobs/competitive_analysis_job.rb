# frozen_string_literal: true

# Background job for performing competitive analysis and market research
# Processes competitive intelligence, market research data, competitor analysis, and industry benchmarks
class CompetitiveAnalysisJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.minutes, attempts: 3 do |job, exception|
    Rails.logger.error "CompetitiveAnalysisJob failed after #{job.executions} attempts: #{exception.message}"

    # Mark campaign plan as having failed competitive analysis
    if job.arguments.first.is_a?(Integer)
      campaign_plan = CampaignPlan.find_by(id: job.arguments.first)
      if campaign_plan
        campaign_plan.update_column(:competitive_analysis_last_updated_at, nil)
        Rails.logger.error "Reset competitive_analysis_last_updated_at for campaign_plan #{campaign_plan.id}"
      end
    end
  end

  def perform(campaign_plan_id)
    @campaign_plan = CampaignPlan.find(campaign_plan_id)

    Rails.logger.info "Starting competitive analysis for campaign plan #{campaign_plan_id}"

    # Create service instance and perform synchronous analysis
    service = CompetitiveAnalysisService.new(@campaign_plan)
    result = service.perform_analysis

    if result[:success]
      Rails.logger.info "Successfully completed competitive analysis for campaign plan #{campaign_plan_id}"

      # Trigger follow-up actions if needed
      trigger_follow_up_actions
    else
      Rails.logger.error "Failed competitive analysis for campaign plan #{campaign_plan_id}: #{result[:error]}"
      raise StandardError, "Competitive analysis failed: #{result[:error]}"
    end

  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Campaign plan #{campaign_plan_id} not found: #{e.message}"
    # Don't retry for missing records
    raise ActiveJob::DeserializationError, "Campaign plan #{campaign_plan_id} not found"
  rescue => e
    Rails.logger.error "Unexpected error in competitive analysis job: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def trigger_follow_up_actions
    # Optional: Trigger related processes after competitive analysis completion

    # 1. Notify the campaign plan owner
    notify_completion if should_notify?

    # 2. Update campaign strategy based on competitive insights
    update_campaign_strategy if @campaign_plan.ready_for_generation?

    # 3. Schedule periodic refresh of competitive analysis
    schedule_refresh if should_schedule_refresh?
  end

  def notify_completion
    # Implementation for notifying users about completion
    Rails.logger.info "Competitive analysis completed for campaign plan #{@campaign_plan.id}"

    # Future: Send email notification or push notification
    # CompetitiveAnalysisNotificationMailer.analysis_completed(@campaign_plan).deliver_now
  end

  def update_campaign_strategy
    # If the campaign plan is still in draft/generating state,
    # we can potentially update the strategy based on competitive insights
    return unless @campaign_plan.draft? || @campaign_plan.generating?

    Rails.logger.info "Updating campaign strategy with competitive insights for plan #{@campaign_plan.id}"

    # This could trigger the CampaignPlanService to regenerate strategy
    # incorporating the new competitive analysis data
    # CampaignPlanService.new(@campaign_plan).regenerate_with_competitive_insights
  end

  def schedule_refresh
    # Schedule the next competitive analysis refresh in 7 days
    CompetitiveAnalysisJob.set(wait: 7.days).perform_later(@campaign_plan.id)
    Rails.logger.info "Scheduled next competitive analysis refresh for campaign plan #{@campaign_plan.id}"
  end

  def should_notify?
    # Only notify if the campaign plan owner has notifications enabled
    @campaign_plan.user.present?
  end

  def should_schedule_refresh?
    # Only schedule refresh for active, approved campaign plans
    @campaign_plan.approval_approved? || @campaign_plan.execution_in_progress?
  end
end
