# Configure secure session store for Rails 8
Rails.application.configure do
  # Use encrypted cookie store with secure settings
  config.session_store :cookie_store,
    key: '_marketer_gen_session',
    expire_after: 2.weeks,
    secure: Rails.env.production?, # Only send over HTTPS in production
    httponly: true,               # Prevent JavaScript access
    same_site: :lax              # CSRF protection while allowing some cross-site usage
end

# Additional session security configuration
Rails.application.config.after_initialize do
  # Clear expired sessions on startup in production
  if Rails.env.production?
    Rails.logger.info "Starting session cleanup background job"
    SessionCleanupJob.perform_later if defined?(SessionCleanupJob)
  end
end