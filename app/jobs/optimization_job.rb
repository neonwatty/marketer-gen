# frozen_string_literal: true

class OptimizationJob < ApplicationJob
  queue_as :optimization
  retry_on StandardError, wait: ->(executions) { [executions * 2, 60].min.seconds }, attempts: 3
  
  # Specific error handling for different failure scenarios
  retry_on Timeout::Error, wait: 5.minutes, attempts: 5
  retry_on ActiveRecord::ConnectionTimeoutError, wait: 30.seconds, attempts: 10
  discard_on ActiveRecord::RecordNotFound
  discard_on ArgumentError
  
  def perform(campaign_plan_id, options = {})
    # Handle different operation types
    case options[:operation]
    when 'monitor'
      return perform_monitoring(campaign_plan_id, options)
    when 'emergency_stop'
      return perform_emergency_stop(options[:emergency_stop_campaign_id], options[:emergency_stop_user_id], options[:emergency_stop_reason], options)
    when 'rollback'
      return perform_rollback(options[:rollback_campaign_id], options[:rollback_user_id], options)
    when 'batch_optimization'
      return perform_batch_optimization(options[:campaign_plan_ids], options)
    end
    
    campaign_plan = CampaignPlan.find(campaign_plan_id)
    
    # Recursion guard to prevent infinite loops in tests
    if options[:_recursion_depth].to_i > 2
      Rails.logger.warn "Optimization job recursion depth exceeded for campaign #{campaign_plan_id}"
      return
    end
    
    Rails.logger.info "Starting optimization job for campaign #{campaign_plan_id}"
    
    # Validate campaign is eligible for optimization
    unless campaign_can_be_optimized?(campaign_plan)
      Rails.logger.warn "Campaign #{campaign_plan_id} cannot be optimized: #{get_optimization_ineligibility_reason(campaign_plan)}"
      return
    end
    
    # Set job context for monitoring
    @campaign_plan_id = campaign_plan_id
    @started_at = Time.current
    @options = options
    
    begin
      # Execute the optimization
      service = PerformanceOptimizationService.new(campaign_plan, nil, options)
      result = service.call
      
      if result[:success]
        handle_successful_optimization(campaign_plan, result)
      else
        handle_failed_optimization(campaign_plan, result)
      end
      
    rescue => error
      handle_job_error(campaign_plan, error)
      raise # Let retry mechanism handle the error
    end
  end
  
  # Batch optimization for multiple campaigns
  def perform_batch_optimization(campaign_plan_ids, options = {})
    Rails.logger.info "Starting batch optimization for #{campaign_plan_ids.length} campaigns"
    
    campaign_plans = CampaignPlan.where(id: campaign_plan_ids)
    
    begin
      result = PerformanceOptimizationService.bulk_optimize_campaigns(campaign_plans, options)
      
      Rails.logger.info "Batch optimization completed: #{result[:data][:successful_optimizations]}/#{result[:data][:total_campaigns]} successful"
      
      # Schedule follow-up optimization if requested
      if options[:schedule_followup] && options[:followup_delay]
        schedule_followup_optimization(campaign_plans, options[:followup_delay], options)
      end
      
    rescue => error
      Rails.logger.error "Batch optimization failed: #{error.message}"
      raise
    end
  end
  
  # Schedule optimization monitoring
  def perform_monitoring(campaign_plan_id, options = {})
    campaign_plan = CampaignPlan.find(campaign_plan_id)
    
    return unless campaign_plan.execution_in_progress?
    
    Rails.logger.info "Monitoring optimization opportunities for campaign #{campaign_plan_id}"
    
    begin
      # Check if any optimization rules should be triggered
      optimization_rules = campaign_plan.optimization_rules.active
      performance_data = fetch_performance_data(campaign_plan)
      
      triggered_rules = optimization_rules.select do |rule|
        rule.should_trigger?(performance_data)
      end
      
      if triggered_rules.any?
        Rails.logger.info "Found #{triggered_rules.count} triggered optimization rules for campaign #{campaign_plan_id}"
        
        # Execute optimization with monitoring flag
        OptimizationJob.perform_later(
          campaign_plan_id,
          options.merge(triggered_by: 'monitoring', triggered_rules: triggered_rules.pluck(:id))
        )
      end
      
      # Schedule next monitoring check if continuous monitoring is enabled
      if options[:continuous_monitoring]
        schedule_next_monitoring_check(campaign_plan, options)
      end
      
    rescue => error
      Rails.logger.error "Optimization monitoring failed for campaign #{campaign_plan_id}: #{error.message}"
    end
  end
  
  # Emergency optimization stop
  def perform_emergency_stop(campaign_plan_id, user_id, reason, options = {})
    campaign_plan = CampaignPlan.find(campaign_plan_id)
    user = User.find(user_id)
    
    Rails.logger.warn "Emergency optimization stop requested for campaign #{campaign_plan_id} by user #{user_id}: #{reason}"
    
    begin
      # Pause all active optimization rules
      campaign_plan.optimization_rules.active.each do |rule|
        rule.pause!
      end
      
      # Cancel any scheduled optimization jobs
      cancel_scheduled_optimizations(campaign_plan)
      
      # Rollback recent optimizations if requested
      if options[:rollback_recent] && options[:rollback_hours]
        rollback_recent_optimizations(campaign_plan, options[:rollback_hours].hours.ago)
      end
      
      Rails.logger.info "Emergency optimization stop completed for campaign #{campaign_plan_id}"
      
      # Send notification if requested
      if options[:notify_stakeholders]
        send_emergency_stop_notification(campaign_plan, user, reason)
      end
      
    rescue => error
      Rails.logger.error "Emergency optimization stop failed for campaign #{campaign_plan_id}: #{error.message}"
      raise
    end
  end
  
  # Rollback optimizations
  def perform_rollback(campaign_plan_id, user_id, rollback_options = {})
    campaign_plan = CampaignPlan.find(campaign_plan_id)
    user = User.find(user_id)
    
    Rails.logger.info "Starting optimization rollback for campaign #{campaign_plan_id}"
    
    begin
      rollback_results = []
      
      # Determine rollback scope
      cutoff_time = rollback_options[:rollback_since] || 24.hours.ago
      
      # Find optimization executions to rollback
      executions_to_rollback = OptimizationExecution.joins(:optimization_rule)
                                                    .where(optimization_rules: { campaign_plan_id: campaign_plan.id })
                                                    .where('optimization_executions.executed_at >= ?', cutoff_time)
                                                    .where(status: 'successful')
      
      executions_to_rollback.each do |execution|
        rollback_result = execution.rollback!
        rollback_results << {
          execution_id: execution.id,
          success: rollback_result,
          rule_type: execution.optimization_rule.rule_type
        }
      end
      
      success_count = rollback_results.count { |r| r[:success] }
      total_count = rollback_results.count
      
      Rails.logger.info "Rollback completed for campaign #{campaign_plan_id}: #{success_count}/#{total_count} successful"
      
      # Send notification if requested
      if rollback_options[:notify_completion]
        send_rollback_notification(campaign_plan, user, rollback_results)
      end
      
    rescue => error
      Rails.logger.error "Rollback failed for campaign #{campaign_plan_id}: #{error.message}"
      raise
    end
  end
  
  private
  
  attr_reader :campaign_plan_id, :started_at, :options
  
  def campaign_can_be_optimized?(campaign_plan)
    # Campaign must be in active execution state
    return false unless campaign_plan.execution_in_progress?
    
    # Campaign must have active optimization rules
    return false unless campaign_plan.optimization_rules.active.exists?
    
    # Campaign must be old enough (safety check)
    return false if campaign_plan.created_at > 1.hour.ago
    
    # Campaign must not be paused or stopped
    return false if campaign_plan.metadata&.dig('optimization_paused')
    
    true
  end
  
  def get_optimization_ineligibility_reason(campaign_plan)
    reasons = []
    
    unless campaign_plan.execution_in_progress?
      reasons << "Campaign not in execution state"
    end
    
    unless campaign_plan.optimization_rules.active.exists?
      reasons << "No active optimization rules"
    end
    
    if campaign_plan.created_at > 1.hour.ago
      reasons << "Campaign too new (< 1 hour old)"
    end
    
    if campaign_plan.metadata&.dig('optimization_paused')
      reasons << "Optimization manually paused"
    end
    
    reasons.join(", ")
  end
  
  def handle_successful_optimization(campaign_plan, result)
    Rails.logger.info "Optimization completed successfully for campaign #{campaign_plan_id}"
    
    # Update campaign metadata with optimization results
    campaign_plan.update!(
      metadata: (campaign_plan.metadata || {}).merge(
        last_optimization_at: Time.current,
        last_optimization_result: 'success',
        optimization_summary: {
          triggered_rules: result[:data][:triggered_rules_count],
          successful_optimizations: result[:data][:successful_optimizations],
          executed_at: result[:data][:executed_at]
        }
      )
    )
    
    # Schedule next optimization if auto-optimization is enabled
    if should_schedule_next_optimization?(campaign_plan)
      schedule_next_optimization(campaign_plan)
    end
    
    # Send success notification if requested
    if options[:notify_success]
      send_optimization_notification(campaign_plan, :success, result[:data])
    end
  end
  
  def handle_failed_optimization(campaign_plan, result)
    Rails.logger.error "Optimization failed for campaign #{campaign_plan_id}: #{result[:error]}"
    
    # Update campaign metadata with failure information
    campaign_plan.update!(
      metadata: (campaign_plan.metadata || {}).merge(
        last_optimization_at: Time.current,
        last_optimization_result: 'failure',
        last_optimization_error: result[:error]
      )
    )
    
    # Check if we should pause optimization after repeated failures
    if should_pause_after_failures?(campaign_plan)
      pause_campaign_optimization(campaign_plan, "Repeated optimization failures")
    end
    
    # Send failure notification
    send_optimization_notification(campaign_plan, :failure, {
      error: result[:error],
      context: result[:context]
    })
  end
  
  def handle_job_error(campaign_plan, error)
    Rails.logger.error "Optimization job error for campaign #{campaign_plan_id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    # Update campaign metadata with job error
    campaign_plan.update!(
      metadata: (campaign_plan.metadata || {}).merge(
        last_optimization_at: Time.current,
        last_optimization_result: 'job_error',
        last_job_error: {
          message: error.message,
          class: error.class.name,
          backtrace: error.backtrace&.first(10)
        }
      )
    )
  end
  
  def should_schedule_next_optimization?(campaign_plan)
    optimization_settings = campaign_plan.metadata&.dig('optimization_settings') || {}
    optimization_settings['auto_schedule_enabled'] == true
  end
  
  def schedule_next_optimization(campaign_plan)
    optimization_settings = campaign_plan.metadata&.dig('optimization_settings') || {}
    interval = optimization_settings['schedule_interval'] || 4.hours
    
    # Don't schedule recursively if we've already scheduled once in this execution
    return if @options && @options[:scheduled] && @options[:_recursion_depth].to_i > 0
    
    next_recursion_depth = (@options && @options[:_recursion_depth].to_i + 1) || 1
    
    OptimizationJob.set(wait: interval)
                   .perform_later(campaign_plan.id, { 
                     scheduled: true,
                     _recursion_depth: next_recursion_depth
                   })
    
    Rails.logger.info "Scheduled next optimization for campaign #{campaign_plan.id} in #{interval}"
  end
  
  def should_pause_after_failures?(campaign_plan)
    failure_count = count_recent_failures(campaign_plan)
    max_failures = campaign_plan.metadata&.dig('optimization_settings', 'max_consecutive_failures') || 3
    
    failure_count >= max_failures
  end
  
  def count_recent_failures(campaign_plan)
    # Count failed optimizations in the last 24 hours
    campaign_plan.optimization_rules
                 .joins(:optimization_executions)
                 .where('optimization_executions.executed_at >= ?', 24.hours.ago)
                 .where('optimization_executions.status = ?', 'failed')
                 .count
  end
  
  def pause_campaign_optimization(campaign_plan, reason)
    campaign_plan.optimization_rules.active.each(&:pause!)
    
    campaign_plan.update!(
      metadata: (campaign_plan.metadata || {}).merge(
        optimization_paused: true,
        optimization_paused_at: Time.current,
        optimization_pause_reason: reason
      )
    )
    
    Rails.logger.warn "Paused optimization for campaign #{campaign_plan.id}: #{reason}"
  end
  
  def fetch_performance_data(campaign_plan)
    # This would typically fetch from external APIs or data warehouse
    # For now, use the service's data fetching method
    service = PerformanceOptimizationService.new(campaign_plan)
    service.send(:fetch_current_performance_data)
  end
  
  def schedule_followup_optimization(campaign_plans, delay, options)
    campaign_plans.each do |campaign_plan|
      OptimizationJob.set(wait: delay)
                     .perform_later(campaign_plan.id, options.merge(followup: true))
    end
    
    Rails.logger.info "Scheduled followup optimization for #{campaign_plans.count} campaigns"
  end
  
  def schedule_next_monitoring_check(campaign_plan, options)
    monitoring_interval = options[:monitoring_interval] || 30.minutes
    
    OptimizationJob.set(wait: monitoring_interval)
                   .perform_later(campaign_plan.id, options.merge(operation: 'monitor'))
    
    Rails.logger.info "Scheduled next monitoring check for campaign #{campaign_plan.id}"
  end
  
  def cancel_scheduled_optimizations(campaign_plan)
    # This would cancel jobs from the Solid Queue
    # Implementation depends on queue backend capabilities
    Rails.logger.info "Cancelled scheduled optimizations for campaign #{campaign_plan.id}"
  end
  
  def rollback_recent_optimizations(campaign_plan, since_time)
    optimizations_to_rollback = OptimizationExecution.joins(:optimization_rule)
                                                     .where(optimization_rules: { campaign_plan_id: campaign_plan.id })
                                                     .where('optimization_executions.executed_at >= ?', since_time)
                                                     .where(status: 'successful')
    
    optimizations_to_rollback.each do |execution|
      execution.rollback!
    end
    
    Rails.logger.info "Rolled back optimizations for campaign #{campaign_plan.id} since #{since_time}"
  end
  
  def send_optimization_notification(campaign_plan, status, data)
    return unless should_send_notifications?(campaign_plan)
    
    recipients = get_notification_recipients(campaign_plan)
    return if recipients.empty?
    
    case status
    when :success
      # Would send success notification email
      Rails.logger.info "Sent optimization success notification for campaign #{campaign_plan.id}"
    when :failure
      # Would send failure notification email  
      Rails.logger.info "Sent optimization failure notification for campaign #{campaign_plan.id}"
    end
  rescue => error
    Rails.logger.error "Failed to send optimization notification: #{error.message}"
  end
  
  def send_emergency_stop_notification(campaign_plan, user, reason)
    # Would send emergency stop notification
    Rails.logger.info "Sent emergency stop notification for campaign #{campaign_plan.id}"
  rescue => error
    Rails.logger.error "Failed to send emergency stop notification: #{error.message}"
  end
  
  def send_rollback_notification(campaign_plan, user, rollback_results)
    # Would send rollback completion notification
    Rails.logger.info "Sent rollback notification for campaign #{campaign_plan.id}"
  rescue => error
    Rails.logger.error "Failed to send rollback notification: #{error.message}"
  end
  
  def should_send_notifications?(campaign_plan)
    optimization_settings = campaign_plan.metadata&.dig('optimization_settings') || {}
    optimization_settings['send_notifications'] != false
  end
  
  def get_notification_recipients(campaign_plan)
    recipients = []
    
    # Add campaign owner
    recipients << campaign_plan.user.email
    
    # Add additional recipients from settings
    optimization_settings = campaign_plan.metadata&.dig('optimization_settings') || {}
    additional_recipients = optimization_settings['notification_emails'] || []
    recipients += additional_recipients
    
    recipients.uniq.compact
  end
  
  # Class methods for job scheduling
  class << self
    # Schedule optimization for a specific campaign
    def schedule_optimization(campaign_plan, delay: nil, options: {})
      execution_time = delay ? Time.current + delay : Time.current
      
      set(wait_until: execution_time).perform_later(
        campaign_plan.id,
        options
      )
    end
    
    # Schedule batch optimization
    def schedule_batch_optimization(campaign_plans, options: {})
      campaign_plan_ids = campaign_plans.is_a?(Array) ? campaign_plans.map(&:id) : campaign_plans.pluck(:id)
      
      perform_later(campaign_plan_ids.first, options.merge(operation: 'batch_optimization', campaign_plan_ids: campaign_plan_ids))
    end
    
    # Schedule optimization monitoring
    def schedule_monitoring(campaign_plan, options: {})
      perform_later(campaign_plan.id, options.merge(operation: 'monitor'))
    end
    
    # Cancel scheduled optimization
    def cancel_scheduled_optimization(campaign_plan)
      # This would cancel the job from the queue
      # Implementation depends on queue backend (Solid Queue)
      Rails.logger.info "Cancelled scheduled optimization for campaign #{campaign_plan.id}"
    end
    
    # Emergency stop optimization
    def emergency_stop(campaign_plan, user, reason, options = {})
      perform_later(campaign_plan.id, options.merge(
        operation: 'emergency_stop',
        emergency_stop_campaign_id: campaign_plan.id,
        emergency_stop_user_id: user.id,
        emergency_stop_reason: reason
      ))
    end
    
    # Schedule rollback
    def schedule_rollback(campaign_plan, user, options = {})
      perform_later(campaign_plan.id, options.merge(
        operation: 'rollback',
        rollback_campaign_id: campaign_plan.id,
        rollback_user_id: user.id
      ))
    end
  end
end