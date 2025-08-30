# Security configuration for Rails 8
Rails.application.configure do
  # CSRF Protection
  config.force_ssl = true if Rails.env.production?
  
  # Permissions Policy (formerly Feature Policy)
  config.permissions_policy do |policy|
    policy.camera      :none
    policy.gyroscope   :none
    policy.microphone  :none
    policy.usb         :none
    policy.fullscreen  :self
    policy.payment     :none
    policy.geolocation :none
  end
end

# Additional security headers
Rails.application.config.after_initialize do
  # Set up security headers middleware
  Rails.application.config.force_ssl = true if Rails.env.production?
  
  # Additional headers will be set in ApplicationController
end