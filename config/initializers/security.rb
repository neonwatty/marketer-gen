# Security configuration for Rails 8
Rails.application.configure do
  # CSRF Protection
  config.force_ssl = true if Rails.env.production?
  
  # Content Security Policy
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    
    # Allow @vite/client to hot reload in development
    if Rails.env.development?
      policy.script_src :self, :https, :unsafe_eval
      policy.connect_src :self, :https, "ws://localhost:*", "ws://127.0.0.1:*"
    end
  end
  
  # Generate session nonces for script and style directives
  config.content_security_policy_nonce_generator = ->(request) {
    SecureRandom.base64(16)
  }
  
  # Report CSP violations
  config.content_security_policy_report_only = false
  
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