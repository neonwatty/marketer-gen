# frozen_string_literal: true

# Background job for executing campaign deployment across platforms
# Handles scheduled execution, monitoring, and error recovery
class CampaignExecutionJob < ApplicationJob
  queue_as :campaign_execution
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Specific error handling for different failure scenarios
  retry_on Timeout::Error, wait: 5.minutes, attempts: 5
  retry_on ActiveRecord::ConnectionTimeoutError, wait: 30.seconds, attempts: 10
  discard_on ActiveRecord::RecordNotFound
  discard_on ArgumentError
  
  # Main execution method
  def perform(execution_schedule_id, options = {})
    execution_schedule = ExecutionSchedule.find(execution_schedule_id)
    
    Rails.logger.info "Starting campaign execution job for schedule #{execution_schedule_id}"
    
    # Validate execution is still valid
    unless execution_schedule.can_be_executed?
      Rails.logger.warn "Execution schedule #{execution_schedule_id} cannot be executed: #{execution_schedule.status}"
      return
    end
    
    # Check execution window
    unless execution_schedule.in_execution_window?
      Rails.logger.info "Execution schedule #{execution_schedule_id} outside execution window, rescheduling"
      reschedule_for_next_window(execution_schedule)
      return
    end
    
    # Set job context for monitoring
    self.execution_schedule_id = execution_schedule_id
    self.started_at = Time.current
    
    begin
      # Execute the campaign deployment
      service = CampaignExecutionService.new(execution_schedule)
      result = service.call
      
      if result[:success]
        handle_successful_execution(execution_schedule, result)
      else
        handle_failed_execution(execution_schedule, result)
      end
      
    rescue => error
      handle_job_error(execution_schedule, error)
      raise # Let retry mechanism handle the error
    end
  end
  
  # Rollback execution job
  def perform_rollback(execution_schedule_id, user_id, options = {})
    execution_schedule = ExecutionSchedule.find(execution_schedule_id)
    user = User.find(user_id)
    
    Rails.logger.info "Starting rollback for execution schedule #{execution_schedule_id}"
    
    begin
      service = CampaignExecutionService.new(execution_schedule)
      result = service.rollback_execution
      
      if result[:success]
        Rails.logger.info "Rollback completed successfully for schedule #{execution_schedule_id}"
        
        # Send notification if requested
        if options[:notify_completion] && options[:notification_email]
          CampaignExecutionMailer.rollback_completed(
            options[:notification_email],
            user,
            execution_schedule,
            result[:data]
          ).deliver_now
        end
      else
        Rails.logger.error "Rollback failed for schedule #{execution_schedule_id}: #{result[:error]}"
        
        # Send error notification
        if options[:notify_failure] && options[:notification_email]
          CampaignExecutionMailer.rollback_failed(
            options[:notification_email],
            user,
            execution_schedule,
            result[:error]
          ).deliver_now
        end
      end
      
    rescue => error
      Rails.logger.error "Rollback job failed for schedule #{execution_schedule_id}: #{error.message}"
      raise
    end
  end
  
  # Monitor execution progress
  def perform_monitoring(execution_schedule_id, options = {})
    execution_schedule = ExecutionSchedule.find(execution_schedule_id)
    
    return unless execution_schedule.executing?
    
    Rails.logger.info "Monitoring execution schedule #{execution_schedule_id}"
    
    begin
      service = CampaignExecutionService.new(execution_schedule)
      status = service.execution_status
      
      # Check for performance issues or optimization opportunities
      if should_apply_optimizations?(status)
        apply_performance_optimizations(execution_schedule, status)
      end
      
      # Schedule next monitoring check
      if execution_schedule.executing?
        CampaignExecutionJob.set(wait: monitoring_interval(options))
                           .perform_later(execution_schedule_id, { operation: 'monitor' })
      end
      
    rescue => error
      Rails.logger.error "Monitoring failed for schedule #{execution_schedule_id}: #{error.message}"
    end
  end
  
  private
  
  attr_accessor :execution_schedule_id, :started_at
  
  def handle_successful_execution(execution_schedule, result)
    Rails.logger.info "Campaign execution completed successfully for schedule #{execution_schedule_id}"
    
    # Mark the execution schedule as completed
    execution_schedule.mark_completed!(nil, result[:data])
    
    # Update campaign plan execution status
    campaign_plan = execution_schedule.campaign_plan
    if campaign_plan.plan_execution_started_at.blank?
      campaign_plan.start_execution!
    end
    
    # Schedule monitoring job if auto-monitoring is enabled
    if execution_schedule.execution_rules.dig('auto_monitor')
      schedule_monitoring_job(execution_schedule)
    end
    
    # Schedule performance optimization job
    if execution_schedule.execution_rules.dig('auto_optimize')
      schedule_optimization_job(execution_schedule)
    end
    
    # Send success notification
    send_execution_notification(execution_schedule, :success, result[:data])
  end
  
  def handle_failed_execution(execution_schedule, result)
    Rails.logger.error "Campaign execution failed for schedule #{execution_schedule_id}: #{result[:error]}"
    
    # Check if we should retry
    if should_retry_execution?(execution_schedule)
      schedule_retry(execution_schedule)
    else
      # Mark as failed since we won't retry
      execution_schedule.mark_failed!(nil, result[:error], result[:context])
      
      # Send failure notification
      send_execution_notification(execution_schedule, :failure, {
        error: result[:error],
        context: result[:context]
      })
    end
  end
  
  def handle_job_error(execution_schedule, error)
    Rails.logger.error "Campaign execution job error for schedule #{execution_schedule_id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Update execution schedule with error
    execution_schedule.mark_failed!(nil, error.message, {
      job_error: true,
      error_class: error.class.name,
      backtrace: error.backtrace&.first(10)
    })
  end
  
  def reschedule_for_next_window(execution_schedule)
    next_execution_time = execution_schedule.next_valid_execution_time
    execution_schedule.update!(
      scheduled_at: next_execution_time,
      next_execution_at: next_execution_time,
      metadata: execution_schedule.metadata.merge(
        rescheduled_at: Time.current,
        rescheduled_reason: 'outside_execution_window'
      )
    )
    
    # Schedule new job
    CampaignExecutionJob.set(wait_until: next_execution_time)
                       .perform_later(execution_schedule.id)
    
    Rails.logger.info "Rescheduled execution schedule #{execution_schedule.id} to #{next_execution_time}"
  end
  
  def should_retry_execution?(execution_schedule)
    execution_schedule.retry_count < 3 && 
    execution_schedule.created_at > 24.hours.ago
  end
  
  def schedule_retry(execution_schedule)
    retry_time = calculate_retry_time(execution_schedule.retry_count)
    
    execution_schedule.update!(
      status: 'scheduled',
      scheduled_at: retry_time,
      metadata: execution_schedule.metadata.merge(
        retry_scheduled_at: Time.current,
        retry_time: retry_time
      )
    )
    
    CampaignExecutionJob.set(wait_until: retry_time)
                       .perform_later(execution_schedule.id, { retry: true })
    
    Rails.logger.info "Scheduled retry for execution schedule #{execution_schedule.id} at #{retry_time}"
  end
  
  def calculate_retry_time(retry_count)
    base_delay = [2 ** retry_count, 60].min.minutes
    Time.current + base_delay + rand(5.minutes)
  end
  
  def schedule_monitoring_job(execution_schedule)
    monitoring_interval = execution_schedule.execution_rules.dig('monitoring_interval') || 30.minutes
    
    CampaignExecutionJob.set(wait: monitoring_interval)
                       .perform_later(execution_schedule.id, { operation: 'monitor' })
    
    Rails.logger.info "Scheduled monitoring job for execution schedule #{execution_schedule.id}"
  end
  
  def schedule_optimization_job(execution_schedule)
    optimization_delay = execution_schedule.execution_rules.dig('optimization_delay') || 2.hours
    
    CampaignExecutionJob.set(wait: optimization_delay)
                       .perform_later(execution_schedule.id, { operation: 'optimize' })
    
    Rails.logger.info "Scheduled optimization job for execution schedule #{execution_schedule.id}"
  end
  
  def should_apply_optimizations?(status)
    # Check if performance metrics indicate optimization is needed
    performance_metrics = status[:performance_metrics]
    return false if performance_metrics.blank?
    
    # Simple optimization triggers
    performance_metrics.any? do |platform, metrics|
      metrics.dig('ctr') && metrics['ctr'] < 1.0 || # CTR less than 1%
      metrics.dig('cpc') && metrics['cpc'] > 5.0    # CPC greater than $5
    end
  end
  
  def apply_performance_optimizations(execution_schedule, status)
    Rails.logger.info "Applying performance optimizations for schedule #{execution_schedule.id}"
    
    # This would contain logic to adjust bids, budgets, targeting, etc.
    # based on performance data and predefined rules
    
    optimization_results = {}
    status[:performance_metrics].each do |platform, metrics|
      if metrics.dig('ctr') && metrics['ctr'] < 1.0
        # Increase bids to improve CTR
        optimization_results[platform] = apply_bid_optimization(execution_schedule, platform, :increase_bids)
      elsif metrics.dig('cpc') && metrics['cpc'] > 5.0
        # Decrease bids to lower CPC
        optimization_results[platform] = apply_bid_optimization(execution_schedule, platform, :decrease_bids)
      end
    end
    
    # Log optimization results
    execution_schedule.update!(
      metadata: execution_schedule.metadata.merge(
        optimization_history: (execution_schedule.metadata['optimization_history'] || []) + [{
          timestamp: Time.current,
          optimizations_applied: optimization_results
        }]
      )
    )
  end
  
  def apply_bid_optimization(execution_schedule, platform, optimization_type)
    # Simplified optimization logic - would integrate with platform APIs
    Rails.logger.info "Applying #{optimization_type} optimization for #{platform}"
    
    {
      platform: platform,
      optimization_type: optimization_type,
      applied_at: Time.current,
      success: true
    }
  end
  
  def monitoring_interval(options)
    options[:monitoring_interval] || 30.minutes
  end
  
  def send_execution_notification(execution_schedule, status, data)
    return unless should_send_notifications?(execution_schedule)
    
    recipients = get_notification_recipients(execution_schedule)
    return if recipients.empty?
    
    case status
    when :success
      recipients.each do |email|
        CampaignExecutionMailer.execution_completed(
          email,
          execution_schedule.created_by,
          execution_schedule,
          data
        ).deliver_now
      end
    when :failure
      recipients.each do |email|
        CampaignExecutionMailer.execution_failed(
          email,
          execution_schedule.created_by,
          execution_schedule,
          data[:error]
        ).deliver_now
      end
    end
  rescue => error
    Rails.logger.error "Failed to send execution notification: #{error.message}"
  end
  
  def should_send_notifications?(execution_schedule)
    execution_schedule.execution_rules.dig('send_notifications') != false
  end
  
  def get_notification_recipients(execution_schedule)
    recipients = []
    
    # Add schedule creator
    recipients << execution_schedule.created_by.email
    
    # Add additional recipients from execution rules
    additional_recipients = execution_schedule.execution_rules.dig('notification_emails') || []
    recipients += additional_recipients
    
    # Add campaign plan owner if different
    if execution_schedule.campaign_plan.user != execution_schedule.created_by
      recipients << execution_schedule.campaign_plan.user.email
    end
    
    recipients.uniq.compact
  end
  
  # Class methods for job scheduling
  class << self
    # Schedule execution for a specific execution schedule
    def schedule_execution(execution_schedule, delay: nil, options: {})
      execution_time = delay ? Time.current + delay : execution_schedule.next_execution_at || execution_schedule.scheduled_at
      
      set(wait_until: execution_time).perform_later(
        execution_schedule.id,
        options
      )
    end
    
    # Schedule rollback for an execution
    def schedule_rollback(execution_schedule, user, options: {})
      perform_later(execution_schedule.id, user.id, options.merge(operation: 'rollback'))
    end
    
    # Schedule monitoring for an active execution
    def schedule_monitoring(execution_schedule, options: {})
      perform_later(execution_schedule.id, options.merge(operation: 'monitor'))
    end
    
    # Bulk schedule multiple executions
    def bulk_schedule_executions(execution_schedules, options: {})
      execution_schedules.each do |schedule|
        schedule_execution(schedule, options: options)
      end
    end
    
    # Cancel scheduled execution
    def cancel_scheduled_execution(execution_schedule)
      # This would cancel the job from the queue
      # Implementation depends on queue backend (Solid Queue)
      Rails.logger.info "Cancelled scheduled execution for schedule #{execution_schedule.id}"
    end
  end
end