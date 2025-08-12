# AI Service Alerting System
# Handles alerts for AI service failures, recovery, and operational issues
class AiAlertingService
  include Singleton

  # Alert severity levels
  SEVERITY_LEVELS = {
    low: 1,
    medium: 2,
    high: 3,
    critical: 4
  }.freeze

  # Alert types and their default configurations
  ALERT_TYPES = {
    provider_failure: {
      severity: :medium,
      cooldown: 5.minutes,
      escalation_threshold: 3,
      description: "AI provider experiencing failures"
    },
    rate_limit_exceeded: {
      severity: :low,
      cooldown: 15.minutes,
      escalation_threshold: 5,
      description: "Rate limits exceeded"
    },
    circuit_breaker_open: {
      severity: :high,
      cooldown: 2.minutes,
      escalation_threshold: 2,
      description: "Circuit breaker opened due to failures"
    },
    fallback_exhausted: {
      severity: :critical,
      cooldown: 1.minute,
      escalation_threshold: 1,
      description: "All fallback providers exhausted"
    },
    degraded_mode_active: {
      severity: :medium,
      cooldown: 10.minutes,
      escalation_threshold: 3,
      description: "Service operating in degraded mode"
    },
    manual_override: {
      severity: :high,
      cooldown: 0,
      escalation_threshold: 1,
      description: "Manual override activated"
    },
    service_recovery: {
      severity: :low,
      cooldown: 0,
      escalation_threshold: 1,
      description: "Service recovered from failures"
    },
    unusual_response_time: {
      severity: :low,
      cooldown: 30.minutes,
      escalation_threshold: 3,
      description: "Unusual response times detected"
    }
  }.freeze

  attr_reader :alert_history, :escalated_alerts

  def initialize
    @alert_history = []
    @escalated_alerts = {}
    @last_alert_times = {}
    @alert_counts = {}
  end

  # Main method to send alerts
  def self.send_alert(alert_type, data = {})
    instance.send_alert(alert_type, data)
  end

  def send_alert(alert_type, data = {})
    return unless valid_alert_type?(alert_type)

    alert_config = ALERT_TYPES[alert_type.to_sym]
    current_time = Time.current

    # Check cooldown period
    if in_cooldown_period?(alert_type, current_time, alert_config[:cooldown])
      Rails.logger.debug "Alert #{alert_type} is in cooldown period, skipping"
      return false
    end

    # Create alert data
    alert_data = build_alert_data(alert_type, alert_config, data, current_time)

    # Check if we should escalate
    should_escalate = check_escalation(alert_type, alert_config)

    # Send the alert
    success = dispatch_alert(alert_data, should_escalate)

    if success
      # Update tracking
      update_alert_tracking(alert_type, current_time, alert_data)
      
      # Log the alert
      log_alert(alert_data, should_escalate)
      
      return true
    end

    false
  end

  # Send recovery notification
  def self.send_recovery_alert(provider, data = {})
    instance.send_recovery_alert(provider, data)
  end

  def send_recovery_alert(provider, data = {})
    recovery_data = data.merge(
      provider: provider,
      message: "AI service #{provider} has recovered",
      recovered_at: Time.current
    )

    send_alert(:service_recovery, recovery_data)
  end

  # Get alert statistics
  def self.alert_statistics(timeframe = 24.hours)
    instance.alert_statistics(timeframe)
  end

  def alert_statistics(timeframe = 24.hours)
    cutoff_time = Time.current - timeframe
    recent_alerts = @alert_history.select { |alert| alert[:timestamp] > cutoff_time }

    stats = {
      total_alerts: recent_alerts.count,
      alerts_by_type: {},
      alerts_by_severity: Hash.new(0),
      escalated_count: 0,
      most_frequent_alert: nil,
      alert_rate: 0.0
    }

    # Analyze alerts
    recent_alerts.each do |alert|
      type = alert[:type]
      severity = alert[:severity]

      stats[:alerts_by_type][type] = (stats[:alerts_by_type][type] || 0) + 1
      stats[:alerts_by_severity][severity] += 1
      stats[:escalated_count] += 1 if alert[:escalated]
    end

    # Find most frequent alert type
    if stats[:alerts_by_type].any?
      stats[:most_frequent_alert] = stats[:alerts_by_type].max_by { |_, count| count }[0]
    end

    # Calculate alert rate (alerts per hour)
    stats[:alert_rate] = (recent_alerts.count / (timeframe.to_f / 1.hour)).round(2)

    stats
  end

  # Clear old alert history
  def self.cleanup_alert_history(older_than = 7.days)
    instance.cleanup_alert_history(older_than)
  end

  def cleanup_alert_history(older_than = 7.days)
    cutoff_time = Time.current - older_than
    initial_count = @alert_history.count

    @alert_history.reject! { |alert| alert[:timestamp] < cutoff_time }
    
    # Also cleanup tracking data
    @last_alert_times.reject! { |_, timestamp| timestamp < cutoff_time }
    
    cleaned_count = initial_count - @alert_history.count
    Rails.logger.info "Cleaned up #{cleaned_count} old alerts from alert history"
    
    cleaned_count
  end

  # Check if service is currently in alert state
  def self.service_alert_status(provider)
    instance.service_alert_status(provider)
  end

  def service_alert_status(provider)
    recent_alerts = @alert_history
      .select { |alert| alert[:data][:provider] == provider }
      .select { |alert| alert[:timestamp] > 1.hour.ago }

    return { status: :healthy, alerts: [] } if recent_alerts.empty?

    critical_alerts = recent_alerts.select { |alert| alert[:severity] == :critical }
    high_alerts = recent_alerts.select { |alert| alert[:severity] == :high }

    if critical_alerts.any?
      { status: :critical, alerts: critical_alerts }
    elsif high_alerts.any?
      { status: :degraded, alerts: high_alerts }
    else
      { status: :warning, alerts: recent_alerts }
    end
  end

  private

  def valid_alert_type?(alert_type)
    ALERT_TYPES.key?(alert_type.to_sym)
  end

  def in_cooldown_period?(alert_type, current_time, cooldown)
    return false if cooldown == 0

    last_alert_time = @last_alert_times[alert_type.to_sym]
    return false unless last_alert_time

    current_time < (last_alert_time + cooldown)
  end

  def build_alert_data(alert_type, alert_config, data, current_time)
    {
      id: SecureRandom.uuid,
      type: alert_type.to_sym,
      severity: alert_config[:severity],
      title: alert_config[:description],
      description: data[:message] || generate_alert_message(alert_type, data),
      timestamp: current_time,
      data: data,
      escalated: false,
      environment: Rails.env,
      application: "marketer-gen"
    }
  end

  def check_escalation(alert_type, alert_config)
    alert_count = (@alert_counts[alert_type.to_sym] || 0) + 1
    @alert_counts[alert_type.to_sym] = alert_count

    alert_count >= alert_config[:escalation_threshold]
  end

  def dispatch_alert(alert_data, should_escalate)
    success_count = 0
    total_channels = 0

    # Send to different channels based on severity and escalation
    channels = determine_alert_channels(alert_data[:severity], should_escalate)

    channels.each do |channel|
      total_channels += 1
      
      begin
        case channel
        when :rails_log
          send_to_rails_log(alert_data, should_escalate)
          success_count += 1
        when :email
          send_to_email(alert_data, should_escalate)
          success_count += 1
        when :slack
          send_to_slack(alert_data, should_escalate)
          success_count += 1
        when :webhook
          send_to_webhook(alert_data, should_escalate)
          success_count += 1
        when :console
          send_to_console(alert_data, should_escalate)
          success_count += 1
        end
      rescue => e
        Rails.logger.error "Failed to send alert via #{channel}: #{e.message}"
      end
    end

    success_count > 0
  end

  def determine_alert_channels(severity, escalated)
    channels = [:rails_log] # Always log to Rails

    case severity
    when :low
      channels << :console if Rails.env.development?
    when :medium
      channels += [:console, :email] if Rails.env.production?
      channels << :console if Rails.env.development?
    when :high
      channels += [:console, :email]
      channels << :slack if escalated && Rails.env.production?
    when :critical
      channels += [:console, :email, :slack]
      channels << :webhook if Rails.env.production?
    end

    channels.uniq
  end

  def send_to_rails_log(alert_data, escalated)
    severity_method = case alert_data[:severity]
                     when :low then :info
                     when :medium then :warn
                     when :high, :critical then :error
                     else :warn
                     end

    escalation_marker = escalated ? " [ESCALATED]" : ""
    Rails.logger.send(severity_method, 
      "[AI ALERT#{escalation_marker}] #{alert_data[:type].upcase}: #{alert_data[:description]}"
    )
  end

  def send_to_console(alert_data, escalated)
    return unless Rails.env.development? || Rails.env.test?

    color = case alert_data[:severity]
           when :low then :blue
           when :medium then :yellow
           when :high then :red
           when :critical then :magenta
           end

    escalation_marker = escalated ? " [ESCALATED]" : ""
    
    puts "\n" + "=" * 60
    puts "🚨 AI SERVICE ALERT#{escalation_marker} 🚨".colorize(color: color, mode: :bold)
    puts "Type: #{alert_data[:type]}".colorize(color: color)
    puts "Severity: #{alert_data[:severity]}".colorize(color: color)
    puts "Time: #{alert_data[:timestamp]}"
    puts "Description: #{alert_data[:description]}"
    puts "Data: #{alert_data[:data].to_json}" if alert_data[:data].any?
    puts "=" * 60 + "\n"
  end

  def send_to_email(alert_data, escalated)
    # In a real application, you'd integrate with an email service
    # For now, just simulate email sending
    
    return unless Rails.env.production?
    
    # Could integrate with ActionMailer, SendGrid, etc.
    Rails.logger.info "EMAIL ALERT: Would send email for #{alert_data[:type]} alert"
    
    # Example integration:
    # AdminMailer.ai_service_alert(alert_data, escalated).deliver_now
  end

  def send_to_slack(alert_data, escalated)
    return unless slack_webhook_url.present?
    
    slack_payload = build_slack_payload(alert_data, escalated)
    
    # In a real application, you'd send HTTP request to Slack webhook
    Rails.logger.info "SLACK ALERT: Would send Slack alert for #{alert_data[:type]}"
    
    # Example integration:
    # HTTParty.post(slack_webhook_url, body: slack_payload.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def send_to_webhook(alert_data, escalated)
    webhook_url = ENV['AI_ALERT_WEBHOOK_URL']
    return unless webhook_url.present?
    
    webhook_payload = alert_data.merge(escalated: escalated)
    
    Rails.logger.info "WEBHOOK ALERT: Would send webhook alert to #{webhook_url}"
    
    # Example integration:
    # HTTParty.post(webhook_url, body: webhook_payload.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def build_slack_payload(alert_data, escalated)
    emoji = case alert_data[:severity]
           when :low then ":information_source:"
           when :medium then ":warning:"
           when :high then ":exclamation:"
           when :critical then ":rotating_light:"
           end

    escalation_text = escalated ? " [ESCALATED]" : ""
    
    {
      username: "AI Service Monitor",
      icon_emoji: emoji,
      text: "#{emoji} AI Service Alert#{escalation_text}",
      attachments: [{
        color: slack_color_for_severity(alert_data[:severity]),
        fields: [
          { title: "Type", value: alert_data[:type], short: true },
          { title: "Severity", value: alert_data[:severity].upcase, short: true },
          { title: "Provider", value: alert_data[:data][:provider], short: true },
          { title: "Environment", value: alert_data[:environment], short: true },
          { title: "Description", value: alert_data[:description], short: false },
          { title: "Time", value: alert_data[:timestamp].strftime("%Y-%m-%d %H:%M:%S %Z"), short: false }
        ],
        footer: "AI Service Monitor",
        ts: alert_data[:timestamp].to_i
      }]
    }
  end

  def slack_color_for_severity(severity)
    case severity
    when :low then "good"
    when :medium then "warning" 
    when :high then "danger"
    when :critical then "#ff0000"
    end
  end

  def generate_alert_message(alert_type, data)
    case alert_type.to_sym
    when :provider_failure
      "Provider #{data[:provider]} failed: #{data[:error] || 'Unknown error'}"
    when :rate_limit_exceeded
      "Rate limit exceeded for #{data[:provider]}. #{data[:limit]} requests per #{data[:period]}"
    when :circuit_breaker_open
      "Circuit breaker opened for #{data[:provider]} after #{data[:failure_count]} failures"
    when :fallback_exhausted
      "All fallback providers exhausted for #{data[:provider]}. Last error: #{data[:last_error]}"
    when :degraded_mode_active
      "Service #{data[:provider]} operating in degraded mode: #{data[:reason]}"
    when :manual_override
      "Manual override activated for #{data[:provider]}: #{data[:reason]}"
    when :service_recovery
      "Service #{data[:provider]} recovered from previous failures"
    when :unusual_response_time
      "Unusual response time detected: #{data[:response_time]}s (avg: #{data[:average_time]}s)"
    else
      "AI service alert: #{data[:message] || 'Unknown issue'}"
    end
  end

  def update_alert_tracking(alert_type, current_time, alert_data)
    @last_alert_times[alert_type.to_sym] = current_time
    @alert_history << alert_data
    
    # Keep only last 1000 alerts in memory
    @alert_history = @alert_history.last(1000) if @alert_history.size > 1000
  end

  def log_alert(alert_data, escalated)
    escalation_text = escalated ? " (escalated)" : ""
    Rails.logger.info "Alert dispatched: #{alert_data[:type]} - #{alert_data[:severity]}#{escalation_text}"
  end

  def slack_webhook_url
    ENV['SLACK_WEBHOOK_URL']
  end
end