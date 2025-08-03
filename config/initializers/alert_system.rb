# frozen_string_literal: true

# Alert System Configuration
Rails.application.config.after_initialize do
  # Only start the scheduler in production or when explicitly enabled
  if Rails.env.production? || ENV["ENABLE_ALERT_SCHEDULER"] == "true"
    # Start the alert system scheduler
    Analytics::Alerts::SchedulerJob.set(wait: 30.seconds).perform_later

    Rails.logger.info "Alert system scheduler started"
  end
end

# Configuration for alert system
Rails.application.config.alert_system = ActiveSupport::OrderedOptions.new

# Default notification settings
Rails.application.config.alert_system.default_notification_channels = %w[email in_app]
Rails.application.config.alert_system.critical_delivery_timeout = 1.minute
Rails.application.config.alert_system.high_delivery_timeout = 5.minutes
Rails.application.config.alert_system.medium_delivery_timeout = 15.minutes
Rails.application.config.alert_system.low_delivery_timeout = 1.hour

# ML threshold settings
Rails.application.config.alert_system.min_sample_size = 100
Rails.application.config.alert_system.default_confidence_level = 0.95
Rails.application.config.alert_system.default_learning_rate = 0.1

# Rate limiting settings
Rails.application.config.alert_system.max_alerts_per_hour = 10
Rails.application.config.alert_system.default_cooldown_minutes = 60

# Cleanup settings
Rails.application.config.alert_system.notification_retention_days = 30
Rails.application.config.alert_system.threshold_retention_days = 90
Rails.application.config.alert_system.alert_instance_retention_days = 365
