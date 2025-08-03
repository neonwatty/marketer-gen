# frozen_string_literal: true

module Analytics
  class AlertMailer < ApplicationMailer
    default from: "alerts@marketergen.com"

    # Send performance alert notification
    def performance_alert(recipient:, subject:, message:, template_data:, alert_instance:)
      @alert_instance = alert_instance
      @alert = alert_instance.performance_alert
      @template_data = template_data
      @message = message
      @recipient = recipient

      # Set priority based on alert severity
      case alert_instance.severity
      when "critical"
        headers["X-Priority"] = "1"
        headers["Importance"] = "high"
      when "high"
        headers["X-Priority"] = "2"
        headers["Importance"] = "high"
      when "medium"
        headers["X-Priority"] = "3"
        headers["Importance"] = "normal"
      when "low"
        headers["X-Priority"] = "4"
        headers["Importance"] = "low"
      end

      # Add custom headers for tracking
      headers["X-Alert-ID"] = alert_instance.id.to_s
      headers["X-Alert-Type"] = @alert.alert_type
      headers["X-Metric-Type"] = @alert.metric_type
      headers["X-Metric-Source"] = @alert.metric_source

      mail(
        to: recipient,
        subject: subject,
        template_name: "performance_alert"
      )
    end

    # Send alert escalation notification
    def alert_escalation(recipient:, alert_instance:)
      @alert_instance = alert_instance
      @alert = alert_instance.performance_alert
      @recipient = recipient

      headers["X-Priority"] = "1"
      headers["Importance"] = "high"
      headers["X-Alert-ID"] = alert_instance.id.to_s
      headers["X-Alert-Escalated"] = "true"

      mail(
        to: recipient,
        subject: "🚨 ESCALATED: #{@alert.name}",
        template_name: "alert_escalation"
      )
    end

    # Send alert resolution notification
    def alert_resolved(recipient:, alert_instance:, resolved_by:)
      @alert_instance = alert_instance
      @alert = alert_instance.performance_alert
      @resolved_by = resolved_by
      @recipient = recipient

      headers["X-Alert-ID"] = alert_instance.id.to_s
      headers["X-Alert-Resolved"] = "true"

      mail(
        to: recipient,
        subject: "✅ Resolved: #{@alert.name}",
        template_name: "alert_resolved"
      )
    end

    # Send daily alert summary
    def daily_summary(recipient:, date:, summary_data:)
      @date = date
      @summary_data = summary_data
      @recipient = recipient

      mail(
        to: recipient,
        subject: "Daily Alert Summary - #{date.strftime('%B %d, %Y')}",
        template_name: "daily_summary"
      )
    end

    # Send alert configuration confirmation
    def alert_created(recipient:, alert:)
      @alert = alert
      @recipient = recipient

      mail(
        to: recipient,
        subject: "Alert Created: #{@alert.name}",
        template_name: "alert_created"
      )
    end

    # Send alert test notification
    def test_alert(recipient:, alert:, test_data:)
      @alert = alert
      @test_data = test_data
      @recipient = recipient

      headers["X-Alert-Test"] = "true"

      mail(
        to: recipient,
        subject: "🧪 Test Alert: #{@alert.name}",
        template_name: "test_alert"
      )
    end
  end
end
