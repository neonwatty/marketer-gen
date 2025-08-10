# AI Service Configuration
Rails.application.configure do
  # AI service configuration
  config.ai_service = ActiveSupport::OrderedOptions.new
  
  # Default provider and model
  config.ai_service.default_provider = ENV.fetch("AI_DEFAULT_PROVIDER", "anthropic").to_sym
  config.ai_service.default_model = ENV.fetch("AI_DEFAULT_MODEL", "claude-3-5-sonnet-20241022")
  
  # Context7 MCP integration settings
  config.ai_service.context7_enabled = ENV.fetch("CONTEXT7_ENABLED", "true") == "true"
  config.ai_service.context7_cache_duration = ENV.fetch("CONTEXT7_CACHE_DURATION", "3600").to_i
  
  # Caching settings
  config.ai_service.enable_caching = ENV.fetch("AI_ENABLE_CACHING", "true") == "true"
  config.ai_service.cache_duration = ENV.fetch("AI_CACHE_DURATION", "1800").to_i
  
  # Request timeouts and retries
  config.ai_service.timeout_seconds = ENV.fetch("AI_TIMEOUT_SECONDS", "60").to_i
  config.ai_service.max_retries = ENV.fetch("AI_MAX_RETRIES", "3").to_i
  
  # Token limits for different operations
  config.ai_service.max_tokens = {
    content_generation: ENV.fetch("AI_MAX_TOKENS_CONTENT", "4000").to_i,
    campaign_planning: ENV.fetch("AI_MAX_TOKENS_CAMPAIGN", "3000").to_i,
    brand_analysis: ENV.fetch("AI_MAX_TOKENS_ANALYSIS", "2000").to_i,
    optimization: ENV.fetch("AI_MAX_TOKENS_OPTIMIZATION", "2000").to_i
  }
  
  # Development and debugging settings
  config.ai_service.debug_mode = Rails.env.development? && ENV.fetch("AI_DEBUG", "false") == "true"
  config.ai_service.log_requests = ENV.fetch("AI_LOG_REQUESTS", "true") == "true"
  
  # Rate limiting (requests per minute)
  config.ai_service.rate_limit = ENV.fetch("AI_RATE_LIMIT", "100").to_i
end

# Configure Rails logger for AI services
if Rails.application.config.ai_service.log_requests
  Rails.logger.tagged("AI Service") do |logger|
    logger.info "AI Service initialized with provider: #{Rails.application.config.ai_service.default_provider}"
    logger.info "Context7 integration: #{Rails.application.config.ai_service.context7_enabled ? 'enabled' : 'disabled'}"
  end
end