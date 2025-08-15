class SecurityMonitoringJob < ApplicationJob
  queue_as :security

  # Monitor all users for suspicious activity patterns
  def perform(time_window = 1.hour)
    Rails.logger.info "[SECURITY_JOB] Starting security monitoring sweep for #{time_window}"
    
    start_time = Time.current
    anomaly_count = 0
    users_monitored = 0
    
    User.find_each do |user|
      begin
        anomalies = SecurityMonitoringService.analyze_user_activity(user.id, time_window)
        
        if anomalies.any?
          anomaly_count += 1
          Rails.logger.warn "[SECURITY_JOB] Anomalies detected for user #{user.id}: #{anomalies.join(', ')}"
        end
        
        users_monitored += 1
      rescue => e
        Rails.logger.error "[SECURITY_JOB] Error monitoring user #{user.id}: #{e.message}"
      end
    end
    
    duration = Time.current - start_time
    
    Rails.logger.info "[SECURITY_JOB] Security monitoring completed in #{duration.round(2)}s: " \
                     "#{users_monitored} users monitored, #{anomaly_count} anomalies detected"
    
    # Schedule next monitoring job if this is a recurring task
    if Rails.env.production?
      SecurityMonitoringJob.set(wait: 15.minutes).perform_later(time_window)
    end
  end
end