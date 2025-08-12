# Content Generator initialization and adapter registration
# This initializer sets up the content generation system with all channel adapters

Rails.application.config.after_initialize do
  # Configure ContentGeneratorRegistry with adapters
  registry = ContentGeneratorRegistry.instance
  
  # Register Social Media Adapter
  begin
    registry.register_adapter(
      :social_media,
      ContentAdapters::SocialMediaAdapter,
      {
        max_length: 280,
        supports_hashtags: true,
        supports_mentions: true,
        optimal_hashtag_count: 3,
        engagement_optimization: true,
        platforms: %w[twitter facebook instagram linkedin tiktok youtube]
      }
    )
    Rails.logger.info "Registered SocialMediaAdapter successfully"
  rescue => e
    Rails.logger.error "Failed to register SocialMediaAdapter: #{e.message}"
  end

  # Register Email Adapter
  begin
    registry.register_adapter(
      :email,
      ContentAdapters::EmailAdapter,
      {
        max_subject_length: 50,
        max_body_length: 2000,
        supports_personalization: true,
        supports_html: true,
        conversion_optimization: true,
        email_types: %w[welcome nurture promotional newsletter transactional re_engagement]
      }
    )
    Rails.logger.info "Registered EmailAdapter successfully"
  rescue => e
    Rails.logger.error "Failed to register EmailAdapter: #{e.message}"
  end

  # Register Ads Adapter
  begin
    registry.register_adapter(
      :ads,
      ContentAdapters::AdsAdapter,
      {
        headline_max_length: 30,
        description_max_length: 90,
        requires_cta: true,
        supports_targeting: true,
        conversion_focused: true,
        platforms: %w[google_ads facebook_ads instagram_ads linkedin_ads twitter_ads microsoft_ads]
      }
    )
    Rails.logger.info "Registered AdsAdapter successfully"
  rescue => e
    Rails.logger.error "Failed to register AdsAdapter: #{e.message}"
  end

  # Configure AI service defaults for content generation
  begin
    registry.configure_ai_service(
      provider: Rails.application.config.ai_service&.dig(:default_provider) || :anthropic,
      model: Rails.application.config.ai_service&.dig(:default_model) || "claude-3-5-sonnet-20241022",
      temperature: 0.7,
      max_tokens: 2000
    )
    Rails.logger.info "Configured ContentGenerator AI service defaults"
  rescue => e
    Rails.logger.error "Failed to configure ContentGenerator AI service: #{e.message}"
  end

  # Perform health check
  begin
    health_status = registry.health_check
    healthy_adapters = health_status.count { |_, status| status[:status] == :healthy }
    total_adapters = health_status.size
    
    Rails.logger.info "ContentGenerator health check: #{healthy_adapters}/#{total_adapters} adapters healthy"
    
    if healthy_adapters < total_adapters
      Rails.logger.warn "Some content adapters failed health check: #{health_status.inspect}"
    end
  rescue => e
    Rails.logger.error "ContentGenerator health check failed: #{e.message}"
  end
end