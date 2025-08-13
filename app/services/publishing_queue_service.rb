class PublishingQueueService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :processing_limit, :retry_limit, :batch_size

  def initialize(processing_limit: 10, retry_limit: 3, batch_size: 5)
    @processing_limit = processing_limit
    @retry_limit = retry_limit
    @batch_size = batch_size
  end

  # Main processing method called by background jobs
  def process_ready_items
    results = {
      processed: 0,
      successful: 0,
      failed: 0,
      retried: 0,
      errors: []
    }

    begin
      # Process ready items
      ready_results = PublishingQueue.process_ready_items(processing_limit)
      ready_results.each do |result|
        results[:processed] += 1
        if result[:result][:success]
          results[:successful] += 1
        else
          results[:failed] += 1
          results[:errors] << {
            queue_id: result[:queue_item].id,
            error: result[:result][:error]
          }
        end
      end

      # Retry failed items that are eligible
      retry_results = PublishingQueue.retry_failed_items
      results[:retried] = retry_results

      # Log processing summary
      log_processing_summary(results)

    rescue => e
      Rails.logger.error "Publishing queue processing error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      results[:errors] << { system_error: e.message }
    end

    results
  end

  # Process items for a specific campaign
  def process_campaign_items(campaign_id)
    campaign_schedules = ContentSchedule.where(campaign_id: campaign_id)
                                      .joins(:publishing_queues)
                                      .where(publishing_queues: { processing_status: ['pending', 'scheduled'] })
                                      .where('publishing_queues.scheduled_for <= ?', Time.current)

    results = { processed: 0, successful: 0, failed: 0 }

    campaign_schedules.find_each do |schedule|
      schedule.publishing_queues.ready_for_processing.each do |queue_item|
        begin
          if queue_item.start_processing!
            result = process_single_item(queue_item)
            results[:processed] += 1
            
            if result[:success]
              results[:successful] += 1
            else
              results[:failed] += 1
            end
          end
        rescue => e
          Rails.logger.error "Error processing campaign item #{queue_item.id}: #{e.message}"
          results[:failed] += 1
        end
      end
    end

    results
  end

  # Process items for a specific platform
  def process_platform_items(platform)
    platform_schedules = ContentSchedule.where(platform: platform)
                                       .joins(:publishing_queues)
                                       .where(publishing_queues: { processing_status: ['pending', 'scheduled'] })
                                       .where('publishing_queues.scheduled_for <= ?', Time.current)

    results = { processed: 0, successful: 0, failed: 0 }

    platform_schedules.find_each(batch_size: batch_size) do |schedule|
      schedule.publishing_queues.ready_for_processing.each do |queue_item|
        begin
          if queue_item.start_processing!
            result = process_single_item(queue_item)
            results[:processed] += 1
            
            if result[:success]
              results[:successful] += 1
            else
              results[:failed] += 1
            end
          end
        rescue => e
          Rails.logger.error "Error processing platform item #{queue_item.id}: #{e.message}"
          results[:failed] += 1
        end
      end
    end

    results
  end

  # Emergency processing for high-priority items
  def process_priority_items
    high_priority_schedules = ContentSchedule.where(priority: [4, 5])
                                           .joins(:publishing_queues)
                                           .where(publishing_queues: { processing_status: ['pending', 'scheduled'] })
                                           .where('publishing_queues.scheduled_for <= ?', Time.current)

    results = { processed: 0, successful: 0, failed: 0 }

    high_priority_schedules.find_each do |schedule|
      schedule.publishing_queues.ready_for_processing.each do |queue_item|
        begin
          queue_item.add_processing_log("High priority processing", level: 'info')
          
          if queue_item.start_processing!
            result = process_single_item(queue_item)
            results[:processed] += 1
            
            if result[:success]
              results[:successful] += 1
            else
              results[:failed] += 1
            end
          end
        rescue => e
          Rails.logger.error "Error processing priority item #{queue_item.id}: #{e.message}"
          results[:failed] += 1
        end
      end
    end

    results
  end

  # Get processing statistics
  def processing_statistics(time_range = 24.hours)
    PublishingQueue.processing_statistics(time_range)
  end

  # Get queue health metrics
  def queue_health
    total_pending = PublishingQueue.where(processing_status: ['pending', 'scheduled']).count
    total_overdue = PublishingQueue.overdue.count
    total_failed = PublishingQueue.failed.count
    recent_success_rate = calculate_recent_success_rate

    health_score = calculate_health_score(total_pending, total_overdue, total_failed, recent_success_rate)

    {
      status: determine_health_status(health_score),
      score: health_score,
      metrics: {
        pending_items: total_pending,
        overdue_items: total_overdue,
        failed_items: total_failed,
        success_rate: recent_success_rate,
        last_processed_at: PublishingQueue.completed.maximum(:completed_at)
      },
      recommendations: generate_health_recommendations(total_pending, total_overdue, total_failed, recent_success_rate)
    }
  end

  # Clean up old records
  def cleanup_old_records(days_old = 7)
    deleted_count = PublishingQueue.cleanup_old_completed(days_old)
    Rails.logger.info "Cleaned up #{deleted_count} old publishing queue records"
    deleted_count
  end

  # Pause processing for maintenance
  def pause_processing
    PublishingQueue.where(processing_status: ['pending', 'scheduled']).update_all(processing_status: 'paused')
    Rails.logger.info "Publishing queue processing paused for maintenance"
  end

  # Resume processing after maintenance
  def resume_processing
    PublishingQueue.where(processing_status: 'paused').update_all(processing_status: 'pending')
    Rails.logger.info "Publishing queue processing resumed"
  end

  # Cancel all pending items for a specific content schedule
  def cancel_schedule_items(content_schedule_id)
    cancelled_count = PublishingQueue.joins(:content_schedule)
                                   .where(content_schedules: { id: content_schedule_id })
                                   .where(processing_status: ['pending', 'scheduled', 'paused'])
                                   .update_all(processing_status: 'cancelled')
    
    Rails.logger.info "Cancelled #{cancelled_count} queue items for content schedule #{content_schedule_id}"
    cancelled_count
  end

  # Reschedule items to a new time
  def reschedule_items(queue_item_ids, new_scheduled_time)
    updated_count = PublishingQueue.where(id: queue_item_ids)
                                 .where(processing_status: ['pending', 'scheduled', 'paused'])
                                 .update_all(
                                   scheduled_for: new_scheduled_time,
                                   processing_status: 'scheduled'
                                 )
    
    Rails.logger.info "Rescheduled #{updated_count} queue items to #{new_scheduled_time}"
    updated_count
  end

  # Force retry specific failed items
  def force_retry_items(queue_item_ids)
    results = { retried: 0, errors: [] }
    
    PublishingQueue.where(id: queue_item_ids, processing_status: 'failed').find_each do |queue_item|
      begin
        if queue_item.retry_processing!
          results[:retried] += 1
        else
          results[:errors] << "Could not retry item #{queue_item.id}"
        end
      rescue => e
        results[:errors] << "Error retrying item #{queue_item.id}: #{e.message}"
      end
    end
    
    results
  end

  # Bulk operations
  def bulk_process_by_batch(batch_id)
    batch_items = PublishingQueue.by_batch(batch_id).ready_for_processing
    results = { processed: 0, successful: 0, failed: 0 }

    batch_items.find_each do |queue_item|
      begin
        if queue_item.start_processing!
          result = process_single_item(queue_item)
          results[:processed] += 1
          
          if result[:success]
            results[:successful] += 1
          else
            results[:failed] += 1
          end
        end
      rescue => e
        Rails.logger.error "Error processing batch item #{queue_item.id}: #{e.message}"
        results[:failed] += 1
      end
    end

    # Update batch statistics
    batch_stats = PublishingQueue.batch_statistics(batch_id)
    Rails.logger.info "Batch #{batch_id} processing complete: #{batch_stats}"

    results
  end

  private

  def process_single_item(queue_item)
    content_schedule = queue_item.content_schedule
    
    queue_item.add_processing_log("Starting processing for #{content_schedule.platform}")
    
    # Get platform-specific publisher
    publisher = get_platform_publisher(content_schedule.platform)
    
    if publisher
      result = publisher.publish(content_schedule)
      
      if result[:success]
        queue_item.add_processing_log("Successfully published", level: 'info')
        queue_item.update_processing_metadata('published_post_id', result[:post_id]) if result[:post_id]
        queue_item.update_processing_metadata('published_url', result[:url]) if result[:url]
        queue_item.complete_processing!
      else
        queue_item.add_processing_log("Publishing failed: #{result[:error]}", level: 'error')
        queue_item.update(error_message: result[:error])
        queue_item.fail_processing!
      end
      
      result
    else
      error_msg = "No publisher available for platform: #{content_schedule.platform}"
      queue_item.add_processing_log(error_msg, level: 'error')
      queue_item.update(error_message: error_msg)
      queue_item.fail_processing!
      
      { success: false, error: error_msg }
    end
  end

  def get_platform_publisher(platform)
    case platform.downcase
    when 'twitter'
      TwitterPublisher.new
    when 'instagram'
      InstagramPublisher.new
    when 'linkedin'
      LinkedinPublisher.new
    when 'facebook'
      FacebookPublisher.new
    when 'youtube'
      YoutubePublisher.new
    when 'tiktok'
      TiktokPublisher.new
    else
      nil
    end
  end

  def log_processing_summary(results)
    if results[:processed] > 0
      Rails.logger.info "Publishing queue processing summary: #{results[:processed]} processed, #{results[:successful]} successful, #{results[:failed]} failed, #{results[:retried]} retried"
      
      if results[:errors].any?
        Rails.logger.warn "Publishing errors: #{results[:errors].take(5)}" # Log first 5 errors
      end
    end
  end

  def calculate_recent_success_rate
    recent_items = PublishingQueue.where('created_at >= ?', 24.hours.ago)
                                 .where(processing_status: ['completed', 'failed'])
    
    return 100.0 if recent_items.count == 0
    
    successful_count = recent_items.completed.count
    total_count = recent_items.count
    
    ((successful_count.to_f / total_count) * 100).round(2)
  end

  def calculate_health_score(pending, overdue, failed, success_rate)
    # Health score calculation (0-100)
    score = 100
    
    # Deduct points for overdue items
    score -= [overdue * 5, 30].min
    
    # Deduct points for failed items
    score -= [failed * 2, 20].min
    
    # Deduct points for low success rate
    if success_rate < 90
      score -= (90 - success_rate)
    end
    
    # Deduct points for high pending queue
    if pending > 100
      score -= [(pending - 100) / 10, 25].min
    end
    
    [score, 0].max
  end

  def determine_health_status(score)
    case score
    when 90..100
      'excellent'
    when 75..89
      'good'
    when 50..74
      'fair'
    when 25..49
      'poor'
    else
      'critical'
    end
  end

  def generate_health_recommendations(pending, overdue, failed, success_rate)
    recommendations = []
    
    if overdue > 10
      recommendations << "#{overdue} items are overdue - consider scaling up processing capacity"
    end
    
    if failed > 20
      recommendations << "High number of failed items (#{failed}) - check platform API connections"
    end
    
    if success_rate < 85
      recommendations << "Success rate is below 85% (#{success_rate}%) - investigate common failure causes"
    end
    
    if pending > 100
      recommendations << "Large queue backlog (#{pending} items) - consider increasing processing frequency"
    end
    
    if recommendations.empty?
      recommendations << "Queue is operating normally"
    end
    
    recommendations
  end

  # Mock publisher classes (would be replaced with real API integrations)
  class TwitterPublisher
    def publish(content_schedule)
      content = content_schedule.content_preview
      
      if content.length > 280
        { success: false, error: "Content exceeds Twitter character limit (#{content.length}/280)" }
      else
        # Mock successful publish
        { 
          success: true, 
          post_id: "twitter_#{SecureRandom.hex(8)}", 
          url: "https://twitter.com/user/status/#{SecureRandom.hex(8)}"
        }
      end
    end
  end

  class InstagramPublisher
    def publish(content_schedule)
      # Mock Instagram publishing with image requirement check
      if content_schedule.content_item.respond_to?(:has_image?) && !content_schedule.content_item.has_image?
        { success: false, error: "Instagram posts require at least one image" }
      else
        { 
          success: true, 
          post_id: "instagram_#{SecureRandom.hex(8)}", 
          url: "https://instagram.com/p/#{SecureRandom.hex(8)}"
        }
      end
    end
  end

  class LinkedinPublisher
    def publish(content_schedule)
      content = content_schedule.content_preview
      
      if content.length > 3000
        { success: false, error: "Content exceeds LinkedIn character limit (#{content.length}/3000)" }
      else
        { 
          success: true, 
          post_id: "linkedin_#{SecureRandom.hex(8)}", 
          url: "https://linkedin.com/posts/#{SecureRandom.hex(8)}"
        }
      end
    end
  end

  class FacebookPublisher
    def publish(content_schedule)
      # Mock Facebook publishing
      { 
        success: true, 
        post_id: "facebook_#{SecureRandom.hex(8)}", 
        url: "https://facebook.com/posts/#{SecureRandom.hex(8)}"
      }
    end
  end

  class YoutubePublisher
    def publish(content_schedule)
      # Mock YouTube publishing with video requirement
      if content_schedule.content_item.respond_to?(:has_video?) && !content_schedule.content_item.has_video?
        { success: false, error: "YouTube posts require video content" }
      else
        { 
          success: true, 
          post_id: "youtube_#{SecureRandom.hex(8)}", 
          url: "https://youtube.com/watch?v=#{SecureRandom.hex(8)}"
        }
      end
    end
  end

  class TiktokPublisher
    def publish(content_schedule)
      # Mock TikTok publishing with video requirement
      if content_schedule.content_item.respond_to?(:has_video?) && !content_schedule.content_item.has_video?
        { success: false, error: "TikTok posts require video content" }
      else
        { 
          success: true, 
          post_id: "tiktok_#{SecureRandom.hex(8)}", 
          url: "https://tiktok.com/@user/video/#{SecureRandom.hex(8)}"
        }
      end
    end
  end
end