class SessionCleanupJob < ApplicationJob
  queue_as :default
  
  # Run session cleanup tasks
  def perform
    Rails.logger.info "Starting session cleanup job"
    
    # Track cleanup metrics
    expired_count = 0
    suspicious_count = 0
    old_sessions_count = 0
    
    begin
      # Clean up expired sessions
      expired_sessions = Session.expired
      expired_count = expired_sessions.count
      expired_sessions.destroy_all
      
      # Clean up suspicious sessions
      suspicious_sessions = Session.suspicious_sessions
      suspicious_count = suspicious_sessions.count
      suspicious_sessions.destroy_all
      
      # Clean up old sessions (keep only recent ones per user)
      old_sessions_count = cleanup_old_sessions
      
      Rails.logger.info "Session cleanup completed: " \
                       "#{expired_count} expired, " \
                       "#{suspicious_count} suspicious, " \
                       "#{old_sessions_count} old sessions removed"
      
    rescue StandardError => e
      Rails.logger.error "Session cleanup job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end
  
  private
  
  def cleanup_old_sessions
    total_removed = 0
    
    User.find_each do |user|
      # Keep only the 10 most recent sessions per user
      old_sessions = user.sessions.order(updated_at: :desc).offset(10)
      count = old_sessions.count
      old_sessions.destroy_all
      total_removed += count
    end
    
    total_removed
  end
end