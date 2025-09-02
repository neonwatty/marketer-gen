# frozen_string_literal: true

# Configuration for AI-powered journey suggestions
Rails.application.configure do
  # Enable AI journey suggestions (set to false to use rule-based only)
  config.ai_journey_suggestions_enabled = ENV.fetch('AI_JOURNEY_SUGGESTIONS_ENABLED', 'true') == 'true'
  
  # LLM provider configuration
  config.ai_journey_llm_provider = ENV.fetch('AI_JOURNEY_LLM_PROVIDER', 'openai')
  
  # Model selection for different tasks
  config.ai_journey_models = {
    suggestions: ENV.fetch('AI_JOURNEY_SUGGESTION_MODEL', 'gpt-4-turbo-preview'),
    content_generation: ENV.fetch('AI_JOURNEY_CONTENT_MODEL', 'gpt-4-turbo-preview'),
    optimization: ENV.fetch('AI_JOURNEY_OPTIMIZATION_MODEL', 'gpt-4-turbo-preview')
  }
  
  # Temperature settings for different tasks (0.0 - 1.0)
  config.ai_journey_temperatures = {
    suggestions: 0.7,      # Balanced creativity for suggestions
    content_generation: 0.8, # More creative for content
    optimization: 0.5      # More deterministic for analysis
  }
  
  # Feature flags for progressive rollout
  config.ai_journey_features = {
    brand_compliance_scoring: true,
    performance_learning: false,
    natural_language_builder: false,
    competitive_intelligence: false,
    a_b_testing: false
  }
  
  # Rate limiting for AI calls (per user per hour)
  config.ai_journey_rate_limits = {
    suggestions: 50,
    content_generation: 30,
    optimization: 10
  }
  
  # Caching configuration
  config.ai_journey_cache = {
    enabled: true,
    ttl: 1.hour,
    brand_context_ttl: 24.hours
  }
  
  # Monitoring and logging
  config.ai_journey_monitoring = {
    log_prompts: Rails.env.development?,
    log_responses: Rails.env.development?,
    track_performance: true,
    alert_on_errors: Rails.env.production?
  }
end