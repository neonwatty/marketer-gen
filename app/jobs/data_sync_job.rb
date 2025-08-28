# frozen_string_literal: true

# Background job for processing data synchronization operations
# Handles large sync operations asynchronously with proper error handling and retry logic
class DataSyncJob < ApplicationJob
  queue_as :default
  
  # Retry on transient errors with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard job if platform connection is not found
  discard_on ActiveRecord::RecordNotFound
  
  # Discard on permanent errors
  discard_on ArgumentError, ActiveJob::DeserializationError

  def perform(platform_connection_id, sync_options = {})
    @platform_connection = PlatformConnection.find(platform_connection_id)
    @sync_options = sync_options.with_indifferent_access
    
    logger.info "Starting data sync for platform #{@platform_connection.platform} (ID: #{platform_connection_id})"
    logger.info "Sync options: #{@sync_options.inspect}"
    
    # Validate platform connection is active
    unless @platform_connection.active?
      logger.error "Platform connection is not active: #{@platform_connection.status}"
      return handle_inactive_connection
    end
    
    # Set up sync monitoring
    sync_start_time = Time.current
    
    begin
      # Perform the synchronization
      sync_result = perform_synchronization
      
      # Log completion
      sync_duration = Time.current - sync_start_time
      logger.info "Data sync completed in #{sync_duration.round(2)} seconds"
      logger.info "Sync results: #{sync_result.inspect}"
      
      # Schedule follow-up sync if needed
      schedule_follow_up_sync(sync_result)
      
      sync_result
      
    rescue => error
      sync_duration = Time.current - sync_start_time
      logger.error "Data sync failed after #{sync_duration.round(2)} seconds: #{error.message}"
      logger.error error.backtrace.join("\n") if Rails.env.development?
      
      # Mark platform connection with error
      @platform_connection.mark_failed!(error.message)
      
      # Re-raise for retry logic
      raise error
    end
  end

  private

  def perform_synchronization
    # Create sync service and execute
    service = DataSynchronizationService.new(@platform_connection, @sync_options)
    result = service.call
    
    # Handle service result
    if result[:success]
      process_successful_sync(result)
    else
      process_failed_sync(result)
    end
    
    result
  end

  def process_successful_sync(result)
    data = result[:data] || {}
    
    # Log sync statistics
    log_sync_statistics(data)
    
    # Handle conflicts if any
    handle_sync_conflicts(data[:conflicts]) if data[:conflicts]&.any?
    
    # Schedule conflict resolution job if needed
    schedule_conflict_resolution if has_unresolved_conflicts?
    
    # Update platform connection metadata
    update_platform_metadata(data)
    
    result
  end

  def process_failed_sync(result)
    logger.error "Sync service failed: #{result[:error]}"
    
    # Mark platform connection as failed
    @platform_connection.mark_failed!(result[:error])
    
    result
  end

  def log_sync_statistics(data)
    stats = {
      synced_entities: data[:synced_entities]&.count || 0,
      conflicts_detected: data[:conflicts]&.count || 0,
      errors_encountered: data[:errors]&.count || 0
    }
    
    logger.info "Sync statistics: #{stats.inspect}"
    
    # Log entity type breakdown
    if data[:synced_entities]&.any?
      entity_breakdown = data[:synced_entities].group_by { |e| e[:entity_type] }
                                              .transform_values(&:count)
      logger.info "Entity type breakdown: #{entity_breakdown.inspect}"
    end
  end

  def handle_sync_conflicts(conflicts)
    return unless conflicts.any?
    
    logger.warn "Detected #{conflicts.count} sync conflicts"
    
    # Group conflicts by entity type
    conflict_groups = conflicts.group_by { |c| c[:entity_type] }
    
    conflict_groups.each do |entity_type, entity_conflicts|
      logger.warn "#{entity_type}: #{entity_conflicts.count} conflicts"
      
      # For critical entities, schedule immediate resolution
      if critical_entity_type?(entity_type)
        schedule_critical_conflict_resolution(entity_conflicts)
      end
    end
    
    # Send notification if too many conflicts
    if conflicts.count > conflict_threshold
      send_conflict_notification(conflicts)
    end
  end

  def schedule_conflict_resolution
    return unless should_auto_resolve_conflicts?
    
    # Schedule conflict resolution job with delay
    ConflictResolutionJob.set(wait: 5.minutes).perform_later(
      @platform_connection.id,
      @sync_options.merge(sync_type: 'conflict_resolution')
    )
    
    logger.info "Scheduled conflict resolution job"
  end

  def schedule_critical_conflict_resolution(conflicts)
    # Immediately schedule resolution for critical conflicts
    CriticalConflictResolutionJob.perform_later(
      @platform_connection.id,
      conflicts.map { |c| c[:sync_record_id] }
    )
    
    logger.info "Scheduled critical conflict resolution for #{conflicts.count} conflicts"
  end

  def schedule_follow_up_sync(result)
    return unless should_schedule_follow_up?(result)
    
    # Calculate delay based on sync results
    delay = calculate_follow_up_delay(result)
    
    # Schedule next sync
    self.class.set(wait: delay).perform_later(
      @platform_connection.id,
      @sync_options.merge(sync_type: 'delta_sync')
    )
    
    logger.info "Scheduled follow-up sync in #{delay} seconds"
  end

  def update_platform_metadata(data)
    metadata_updates = {
      last_job_completed_at: Time.current,
      last_job_duration: job_duration,
      last_sync_statistics: {
        synced_entities: data[:synced_entities]&.count || 0,
        conflicts: data[:conflicts]&.count || 0,
        errors: data[:errors]&.count || 0
      }
    }
    
    current_metadata = @platform_connection.metadata || {}
    @platform_connection.update!(
      metadata: current_metadata.merge(metadata_updates)
    )
  end

  def handle_inactive_connection
    logger.warn "Skipping sync for inactive platform connection"
    
    {
      success: false,
      error: "Platform connection is not active",
      platform: @platform_connection.platform,
      status: @platform_connection.status
    }
  end

  def send_conflict_notification(conflicts)
    # Send notification to user about conflicts requiring attention
    ConflictNotificationMailer.conflict_alert(
      @platform_connection.user,
      @platform_connection,
      conflicts
    ).deliver_later
    
    logger.info "Sent conflict notification for #{conflicts.count} conflicts"
  end

  def has_unresolved_conflicts?
    @platform_connection.sync_records.with_conflicts.exists?
  end

  def should_auto_resolve_conflicts?
    @sync_options[:auto_resolve_conflicts] != false
  end

  def should_schedule_follow_up?(result)
    return false unless result[:success]
    return false if @sync_options[:one_time_sync]
    
    # Schedule follow-up for continuous sync scenarios
    %w[delta_sync intelligent].include?(@sync_options[:sync_type])
  end

  def calculate_follow_up_delay(result)
    base_delay = case @sync_options[:sync_frequency]
                 when 'hourly'
                   1.hour
                 when 'daily'
                   1.day
                 when 'weekly'
                   1.week
                 else
                   4.hours # default
                 end
    
    # Adjust delay based on sync results
    data = result[:data] || {}
    
    if data[:errors]&.any?
      # Increase delay if there were errors
      base_delay * 2
    elsif data[:conflicts]&.any?
      # Slightly increase delay if there were conflicts
      base_delay * 1.5
    else
      base_delay
    end
  end

  def critical_entity_type?(entity_type)
    %w[campaigns].include?(entity_type)
  end

  def conflict_threshold
    @sync_options[:conflict_threshold] || 10
  end

  def job_duration
    return 0 unless job_started_at
    Time.current - job_started_at
  end

  def job_started_at
    @job_started_at ||= Time.current
  end
end