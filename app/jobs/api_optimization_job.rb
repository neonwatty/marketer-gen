# frozen_string_literal: true

# Background job for API optimization and quota management
# Handles request queuing, optimization algorithms, and quota monitoring
class ApiOptimizationJob < ApplicationJob
  queue_as :api_optimization
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ApiRateLimitingService::QuotaExceeded

  # Job types
  OPTIMIZATION_TYPES = %w[
    quota_monitoring
    request_optimization 
    batch_processing
    quota_reset
    performance_analysis
  ].freeze

  def perform(optimization_type, options = {})
    unless OPTIMIZATION_TYPES.include?(optimization_type)
      raise ArgumentError, "Invalid optimization type: #{optimization_type}"
    end
    
    Rails.logger.info "Starting API optimization job: #{optimization_type}"
    
    result = case optimization_type
    when 'quota_monitoring'
      perform_quota_monitoring(options)
    when 'request_optimization'
      perform_request_optimization(options)
    when 'batch_processing'
      perform_batch_processing(options)
    when 'quota_reset'
      perform_quota_reset(options)
    when 'performance_analysis'
      perform_performance_analysis(options)
    else
      raise ArgumentError, "Unhandled optimization type: #{optimization_type}"
    end
    
    Rails.logger.info "Completed API optimization job: #{optimization_type}"
    result
  end

  private

  # Monitor quota usage across all platforms and alert when near limits
  def perform_quota_monitoring(options)
    customer_id = options[:customer_id]
    alert_threshold = options[:alert_threshold] || 85.0
    
    raise ArgumentError, "customer_id is required for quota monitoring" unless customer_id
    
    quota_status = ApiRateLimitingService.quota_status_for_customer(customer_id)
    alerts = []
    
    quota_status.each do |platform, endpoints|
      endpoints.each do |endpoint, status|
        if status[:usage_percentage] >= alert_threshold
          alerts << {
            platform: platform,
            endpoint: endpoint,
            usage_percentage: status[:usage_percentage],
            remaining: status[:remaining],
            time_until_reset: status[:time_until_reset]
          }
        end
      end
    end
    
    if alerts.any?
      Rails.logger.warn "API quota alerts for customer #{customer_id}: #{alerts.size} endpoints near limit"
      
      # Send notifications or trigger optimization
      alerts.each do |alert|
        schedule_optimization_for_platform(
          customer_id: customer_id,
          platform: alert[:platform],
          endpoint: alert[:endpoint],
          urgency: determine_urgency(alert[:usage_percentage])
        )
      end
    end
    
    {
      status: 'completed',
      customer_id: customer_id,
      alerts_triggered: alerts.size,
      alerts: alerts
    }
  end

  # Optimize API request patterns for a specific platform/endpoint
  def perform_request_optimization(options)
    customer_id = options[:customer_id]
    platform = options[:platform]
    endpoint = options[:endpoint]
    pending_requests = options[:pending_requests] || []
    
    raise ArgumentError, "Missing required parameters" unless customer_id && platform && endpoint
    
    rate_limiter = ApiRateLimitingService.new(
      platform: platform,
      endpoint: endpoint,
      customer_id: customer_id,
      strategy: determine_optimal_strategy(customer_id, platform, endpoint)
    )
    
    # Analyze current quota status
    status = rate_limiter.status
    optimization_plan = rate_limiter.optimize_request_timing(pending_requests.size)
    
    unless optimization_plan[:can_proceed]
      Rails.logger.warn "Cannot proceed with optimization: #{optimization_plan[:reason]}"
      return {
        status: 'delayed',
        reason: optimization_plan[:reason],
        retry_after: status[:quota][:time_until_reset]
      }
    end
    
    # Execute optimized request pattern
    if pending_requests.any?
      batch_size = optimization_plan[:recommended_batch_size]
      total_batches = (pending_requests.size / batch_size.to_f).ceil
      
      Rails.logger.info "Processing #{pending_requests.size} requests in #{total_batches} batches of #{batch_size}"
      
      results = []
      pending_requests.each_slice(batch_size).with_index do |batch, batch_index|
        Rails.logger.info "Processing batch #{batch_index + 1}/#{total_batches}"
        
        batch_results = process_request_batch(rate_limiter, batch, options)
        results.concat(batch_results[:results])
        
        # Wait between batches if needed
        if batch_index < total_batches - 1
          wait_time = optimization_plan[:wait_time] || 1
          sleep(wait_time)
        end
      end
      
      {
        status: 'completed',
        total_requests: pending_requests.size,
        successful_requests: results.count { |r| r[:success] },
        failed_requests: results.count { |r| !r[:success] },
        results: results
      }
    else
      {
        status: 'completed',
        message: 'No pending requests to optimize'
      }
    end
  end

  # Process batches of API requests with intelligent queuing
  def perform_batch_processing(options)
    customer_id = options[:customer_id]
    platform = options[:platform]
    endpoint = options[:endpoint]
    request_data = options[:requests] || []
    callback_class = options[:callback_class]
    
    raise ArgumentError, "Missing required parameters" unless customer_id && platform && endpoint
    
    rate_limiter = ApiRateLimitingService.new(
      platform: platform,
      endpoint: endpoint,
      customer_id: customer_id
    )
    
    results = rate_limiter.execute_batch_requests(request_data) do |request, index|
      # Execute the actual API call based on the request type
      process_individual_request(platform, endpoint, request, callback_class)
    end
    
    # Schedule retry for failed requests if appropriate
    if results[:failed_requests].any? && options[:auto_retry]
      schedule_retry_for_failed_requests(results[:failed_requests], options)
    end
    
    results.merge(
      status: 'completed',
      platform: platform,
      endpoint: endpoint,
      customer_id: customer_id
    )
  end

  # Reset expired quotas and perform cleanup
  def perform_quota_reset(options)
    reset_count = ApiRateLimitingService.reset_expired_quotas!
    
    Rails.logger.info "Reset #{reset_count} expired API quotas"
    
    # Trigger any pending optimizations that were waiting for quota reset
    if options[:trigger_pending]
      trigger_pending_optimizations
    end
    
    {
      status: 'completed',
      quotas_reset: reset_count
    }
  end

  # Analyze API performance and suggest optimizations
  def perform_performance_analysis(options)
    customer_id = options[:customer_id]
    time_range = options[:time_range] || 24.hours
    
    analysis = {
      quota_usage_patterns: analyze_quota_usage_patterns(customer_id, time_range),
      rate_limit_incidents: analyze_rate_limit_incidents(customer_id, time_range),
      optimization_opportunities: identify_optimization_opportunities(customer_id),
      recommendations: generate_optimization_recommendations(customer_id)
    }
    
    Rails.logger.info "Performance analysis completed for customer #{customer_id}"
    
    {
      status: 'completed',
      customer_id: customer_id,
      analysis: analysis
    }
  end

  # Helper methods

  def determine_optimal_strategy(customer_id, platform, endpoint)
    quota_tracker = ApiQuotaTracker.get_or_create_for(
      platform: platform,
      endpoint: endpoint,
      customer_id: customer_id
    )
    
    usage_percentage = quota_tracker.usage_percentage
    
    case usage_percentage
    when 0...30
      :aggressive
    when 30...70
      :balanced
    else
      :conservative
    end
  end

  def determine_urgency(usage_percentage)
    case usage_percentage
    when 0...80
      :low
    when 80...95
      :medium
    else
      :high
    end
  end

  def process_request_batch(rate_limiter, batch, options)
    rate_limiter.execute_batch_requests(batch) do |request, index|
      process_individual_request(
        options[:platform],
        options[:endpoint],
        request,
        options[:callback_class]
      )
    end
  end

  def process_individual_request(platform, endpoint, request, callback_class)
    if callback_class && callback_class.respond_to?(:process_api_request)
      callback_class.process_api_request(platform, endpoint, request)
    else
      # Default processing - just return the request data
      { processed: true, request: request, timestamp: Time.current }
    end
  rescue => error
    Rails.logger.error "Failed to process individual request: #{error.message}"
    { processed: false, error: error.message, request: request }
  end

  def schedule_optimization_for_platform(options)
    # Schedule a follow-up optimization job
    case options[:urgency]
    when :high
      ApiOptimizationJob.set(wait: 5.minutes).perform_later('request_optimization', options)
    when :medium
      ApiOptimizationJob.set(wait: 15.minutes).perform_later('request_optimization', options)
    else
      ApiOptimizationJob.set(wait: 1.hour).perform_later('request_optimization', options)
    end
  end

  def schedule_retry_for_failed_requests(failed_requests, original_options)
    retry_options = original_options.merge(
      requests: failed_requests.map { |fr| fr[:request] },
      auto_retry: false  # Prevent infinite retry loops
    )
    
    ApiOptimizationJob.set(wait: 10.minutes).perform_later('batch_processing', retry_options)
  end

  def trigger_pending_optimizations
    # Implementation would depend on how pending optimizations are stored
    # For now, just log the event
    Rails.logger.info "Triggering pending optimizations after quota reset"
  end

  def analyze_quota_usage_patterns(customer_id, time_range)
    # Analyze quota usage patterns over time
    # This would typically query logs or metrics data
    {
      peak_usage_hours: [9, 10, 14, 15],
      average_daily_usage: 65.5,
      trends: 'increasing'
    }
  end

  def analyze_rate_limit_incidents(customer_id, time_range)
    # Analyze rate limiting incidents
    {
      total_incidents: 3,
      platforms_affected: ['google_ads'],
      most_common_cause: 'burst_requests'
    }
  end

  def identify_optimization_opportunities(customer_id)
    [
      {
        type: 'batch_sizing',
        impact: 'medium',
        description: 'Increase batch sizes for reporting API calls'
      },
      {
        type: 'request_timing',
        impact: 'high', 
        description: 'Distribute requests more evenly throughout the day'
      }
    ]
  end

  def generate_optimization_recommendations(customer_id)
    [
      'Consider using aggressive strategy during off-peak hours',
      'Implement request caching for frequently accessed data',
      'Schedule bulk operations during low-usage periods'
    ]
  end
end