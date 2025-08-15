class SecurityReportJob < ApplicationJob
  queue_as :security

  # Generate daily security reports
  def perform(report_period = 24.hours)
    Rails.logger.info "[SECURITY_REPORT_JOB] Generating security report for #{report_period}"
    
    begin
      report = SecurityMonitoringService.generate_security_report(report_period)
      
      # Store report in cache for admin access
      cache_key = "security_report:#{Date.current.strftime('%Y-%m-%d')}"
      Rails.cache.write(cache_key, report, expires_in: 7.days)
      
      # Log summary
      Rails.logger.info "[SECURITY_REPORT_JOB] Report generated: " \
                       "#{report[:total_alerts]} total alerts, " \
                       "#{report[:alerts_by_severity][:critical]} critical, " \
                       "#{report[:alerts_by_severity][:high]} high severity"
      
      # In production, could email report to security team
      if Rails.env.production? && report[:alerts_by_severity][:critical] > 0
        # SecurityMailer.daily_report(report).deliver_now
        Rails.logger.warn "[SECURITY_REPORT_JOB] Critical alerts detected - consider immediate review"
      end
      
      # Schedule next report (daily)
      SecurityReportJob.set(wait: 24.hours).perform_later(report_period)
      
    rescue => e
      Rails.logger.error "[SECURITY_REPORT_JOB] Failed to generate security report: #{e.message}"
      
      # Retry in 1 hour if failed
      SecurityReportJob.set(wait: 1.hour).perform_later(report_period)
    end
  end
end