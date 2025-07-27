class ActivityReportService
  attr_reader :user, :start_date, :end_date
  
  def initialize(user, start_date: 30.days.ago, end_date: Time.current)
    @user = user
    @start_date = start_date.beginning_of_day
    @end_date = end_date.end_of_day
  end
  
  # Class method for recurring job
  def self.generate_daily_reports
    Rails.logger.info "Generating daily activity reports..."
    
    # Generate reports for all admin users
    User.admin.find_each do |admin|
      report = new(admin, start_date: 1.day.ago).generate_report
      
      # Send email if configured
      if Rails.application.config.activity_alerts.enabled && admin.notification_email?
        AdminMailer.daily_activity_report(admin, report).deliver_later
      end
      
      # Log completion
      ActivityLogger.log(:info, "Daily report generated for admin", {
        admin_id: admin.id,
        total_activities: report[:summary][:total_activities]
      })
    end
    
    Rails.logger.info "Daily activity reports completed."
  end
  
  def generate_report
    {
      summary: generate_summary,
      activity_breakdown: activity_breakdown,
      suspicious_activities: suspicious_activity_summary,
      performance_metrics: performance_metrics,
      security_events: security_events,
      access_patterns: access_patterns,
      device_usage: device_usage,
      recommendations: generate_recommendations
    }
  end
  
  def generate_summary
    activities = user_activities
    
    {
      total_activities: activities.count,
      date_range: {
        start: start_date,
        end: end_date
      },
      most_active_day: most_active_day(activities),
      average_daily_activities: average_daily_activities(activities),
      suspicious_count: activities.suspicious.count,
      failed_requests: activities.failed_requests.count,
      unique_ips: activities.distinct.count(:ip_address),
      unique_sessions: activities.distinct.count(:session_id)
    }
  end
  
  def activity_breakdown
    activities = user_activities
    
    # Group by controller and action
    breakdown = activities
      .group(:controller, :action)
      .count
      .map { |k, v| { controller: k[0], action: k[1], count: v } }
      .sort_by { |item| -item[:count] }
    
    # Add percentage
    total = activities.count
    breakdown.each do |item|
      item[:percentage] = ((item[:count].to_f / total) * 100).round(2)
    end
    
    breakdown
  end
  
  def suspicious_activity_summary
    suspicious = user_activities.suspicious
    
    return { count: 0, events: [] } if suspicious.empty?
    
    {
      count: suspicious.count,
      events: suspicious.map do |activity|
        {
          occurred_at: activity.occurred_at,
          action: activity.full_action,
          ip_address: activity.ip_address,
          reasons: activity.metadata['suspicious_reasons'] || [],
          user_agent: activity.user_agent
        }
      end,
      patterns: analyze_suspicious_patterns(suspicious)
    }
  end
  
  def performance_metrics
    activities = user_activities.where.not(response_time: nil)
    
    return {} if activities.empty?
    
    response_times = activities.pluck(:response_time)
    
    {
      average_response_time: (response_times.sum / response_times.size * 1000).round(2),
      median_response_time: (median(response_times) * 1000).round(2),
      slowest_actions: slowest_actions(activities),
      response_time_distribution: response_time_distribution(response_times)
    }
  end
  
  def security_events
    events = []
    
    # Failed login attempts
    failed_logins = user_activities
      .where(controller: 'sessions', action: 'create')
      .failed_requests
    
    if failed_logins.any?
      events << {
        type: 'failed_login_attempts',
        count: failed_logins.count,
        last_attempt: failed_logins.maximum(:occurred_at),
        ip_addresses: failed_logins.distinct.pluck(:ip_address)
      }
    end
    
    # Authorization failures
    auth_failures = user_activities
      .where("metadata LIKE ?", '%NotAuthorizedError%')
    
    if auth_failures.any?
      events << {
        type: 'authorization_failures',
        count: auth_failures.count,
        resources: auth_failures.map { |a| a.full_action }.uniq
      }
    end
    
    # Account lockouts
    if user.locked_at.present? && user.locked_at >= start_date
      events << {
        type: 'account_locked',
        locked_at: user.locked_at,
        reason: user.lock_reason
      }
    end
    
    events
  end
  
  def access_patterns
    activities = user_activities
    
    # Group by hour of day
    hourly_pattern = activities
      .group_by { |a| a.occurred_at.hour }
      .transform_values(&:count)
      .sort.to_h
    
    # Group by day of week
    daily_pattern = activities
      .group_by { |a| a.occurred_at.strftime('%A') }
      .transform_values(&:count)
    
    # Most accessed resources
    top_resources = activities
      .group(:request_path)
      .count
      .sort_by { |_, count| -count }
      .first(10)
      .to_h
    
    {
      hourly_distribution: hourly_pattern,
      daily_distribution: daily_pattern,
      top_resources: top_resources,
      access_times: {
        first_access: activities.minimum(:occurred_at),
        last_access: activities.maximum(:occurred_at),
        most_active_hour: hourly_pattern.max_by { |_, v| v }&.first,
        most_active_day: daily_pattern.max_by { |_, v| v }&.first
      }
    }
  end
  
  def device_usage
    activities = user_activities
    
    {
      devices: activities.group(:device_type).count,
      browsers: activities.group(:browser_name).count,
      operating_systems: activities.group(:os_name).count,
      unique_user_agents: activities.distinct.count(:user_agent)
    }
  end
  
  private
  
  def user_activities
    @user_activities ||= user.activities
      .where(occurred_at: start_date..end_date)
      .includes(:user)
  end
  
  def most_active_day(activities)
    return nil if activities.empty?
    
    activities
      .group_by { |a| a.occurred_at.to_date }
      .max_by { |_, acts| acts.count }
      &.first
  end
  
  def average_daily_activities(activities)
    days = ((end_date - start_date) / 1.day).ceil
    (activities.count.to_f / days).round(2)
  end
  
  def analyze_suspicious_patterns(suspicious_activities)
    patterns = {}
    
    # Group by reason
    reasons = suspicious_activities
      .flat_map { |a| a.metadata['suspicious_reasons'] || [] }
      .tally
    
    patterns[:by_reason] = reasons
    
    # Time-based patterns
    patterns[:by_hour] = suspicious_activities
      .group_by { |a| a.occurred_at.hour }
      .transform_values(&:count)
    
    # IP-based patterns
    patterns[:by_ip] = suspicious_activities
      .group(:ip_address)
      .count
      .sort_by { |_, count| -count }
      .first(5)
      .to_h
    
    patterns
  end
  
  def slowest_actions(activities)
    activities
      .order(response_time: :desc)
      .limit(10)
      .map do |activity|
        {
          action: activity.full_action,
          response_time_ms: (activity.response_time * 1000).round(2),
          occurred_at: activity.occurred_at,
          path: activity.request_path
        }
      end
  end
  
  def response_time_distribution(times)
    return {} if times.empty?
    
    # Convert to milliseconds
    times_ms = times.map { |t| t * 1000 }
    
    {
      under_100ms: times_ms.count { |t| t < 100 },
      '100_500ms': times_ms.count { |t| t >= 100 && t < 500 },
      '500_1000ms': times_ms.count { |t| t >= 500 && t < 1000 },
      over_1000ms: times_ms.count { |t| t >= 1000 }
    }
  end
  
  def median(array)
    return nil if array.empty?
    
    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
  
  def generate_recommendations
    recommendations = []
    activities = user_activities
    
    # Check for suspicious activity patterns
    if activities.suspicious.count > 5
      recommendations << {
        type: 'security',
        priority: 'high',
        message: 'Multiple suspicious activities detected. Review security settings and consider enabling two-factor authentication.'
      }
    end
    
    # Check for unusual access patterns
    night_activities = activities.select { |a| a.occurred_at.hour.between?(0, 5) }
    if night_activities.count > activities.count * 0.2
      recommendations << {
        type: 'security',
        priority: 'medium',
        message: 'Significant activity during unusual hours detected. Verify these accesses were authorized.'
      }
    end
    
    # Check for multiple IP addresses
    ip_count = activities.distinct.count(:ip_address)
    if ip_count > 10
      recommendations << {
        type: 'security',
        priority: 'medium',
        message: "Activity from #{ip_count} different IP addresses. Consider reviewing access locations."
      }
    end
    
    # Performance recommendations
    slow_requests = activities.where('response_time > ?', 2.0)
    if slow_requests.count > activities.count * 0.1
      recommendations << {
        type: 'performance',
        priority: 'low',
        message: 'More than 10% of requests are slow. Consider optimizing frequently accessed pages.'
      }
    end
    
    recommendations
  end
end