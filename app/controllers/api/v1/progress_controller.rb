class Api::V1::ProgressController < ApplicationController
  before_action :require_authentication
  
  def campaign_plan_progress
    campaign_plan = Current.user.campaign_plans.find(params[:id])
    
    render json: {
      status: campaign_plan.status,
      percentage: campaign_plan.generation_progress_percentage,
      current_step: campaign_plan.current_generation_step,
      steps: campaign_plan.generation_steps,
      message: campaign_plan.generation_status_message,
      estimated_time_remaining: campaign_plan.estimated_time_remaining,
      last_updated: campaign_plan.metadata&.dig('generation_progress', 'last_updated'),
      completed_at: campaign_plan.metadata&.dig('generation_completed_at'),
      duration: campaign_plan.generation_duration&.round(2)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Campaign plan not found' }, status: :not_found
  end

  def task_progress
    # Generic progress endpoint for any long-running task
    task_id = params[:task_id]
    task_type = params[:task_type] || 'campaign_plan'
    
    case task_type
    when 'campaign_plan'
      campaign_plan = Current.user.campaign_plans.find(task_id)
      render json: build_campaign_plan_progress_response(campaign_plan)
    else
      render json: { error: 'Unknown task type' }, status: :bad_request
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Task not found' }, status: :not_found
  end

  private

  def build_campaign_plan_progress_response(campaign_plan)
    {
      task_id: campaign_plan.id,
      task_type: 'campaign_plan',
      status: campaign_plan.status,
      percentage: campaign_plan.generation_progress_percentage,
      current_step: campaign_plan.current_generation_step,
      total_steps: campaign_plan.generation_steps.length,
      steps: campaign_plan.generation_steps,
      message: campaign_plan.generation_status_message,
      estimated_time_remaining: campaign_plan.estimated_time_remaining,
      metadata: {
        last_updated: campaign_plan.metadata&.dig('generation_progress', 'last_updated'),
        started_at: campaign_plan.metadata&.dig('generation_started_at'),
        completed_at: campaign_plan.metadata&.dig('generation_completed_at'),
        failed_at: campaign_plan.metadata&.dig('generation_failed_at'),
        duration: campaign_plan.generation_duration&.round(2),
        error_message: campaign_plan.metadata&.dig('error_message')
      }
    }
  end
end