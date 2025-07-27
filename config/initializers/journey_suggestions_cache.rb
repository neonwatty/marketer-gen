# Journey Suggestions Caching Configuration
Rails.application.configure do
  # Configure cache settings for journey suggestions
  config.after_initialize do
    # Ensure cache store is available
    if Rails.cache.respond_to?(:options)
      # Set up cache key patterns for journey suggestions
      Rails.application.config.journey_suggestions = {
        cache_ttl: {
          suggestions: 1.hour,
          insights: 6.hours,
          analytics: 30.minutes,
          feedback_summary: 15.minutes
        },
        cache_patterns: {
          suggestions: "journey_suggestions:%{journey_id}:%{user_id}:%{provider}:%{filters_hash}",
          insights: "journey_insights:%{journey_id}:%{type}",
          analytics: "journey_analytics:%{journey_id}:%{date_range}",
          feedback: "journey_feedback:%{journey_id}:%{period}"
        },
        # Enable cache warming for active journeys
        cache_warming: {
          enabled: Rails.env.production?,
          batch_size: 10,
          interval: 2.hours
        }
      }
    end
  end
end

# Cache helper methods
module JourneySuggestionsCacheHelper
  extend ActiveSupport::Concern

  class_methods do
    def cache_key_for_suggestions(journey_id:, user_id:, provider:, filters: {})
      pattern = Rails.application.config.journey_suggestions[:cache_patterns][:suggestions]
      filters_hash = Digest::MD5.hexdigest(filters.to_json)
      
      pattern % {
        journey_id: journey_id,
        user_id: user_id,
        provider: provider,
        filters_hash: filters_hash
      }
    end

    def cache_key_for_insights(journey_id:, type:)
      pattern = Rails.application.config.journey_suggestions[:cache_patterns][:insights]
      pattern % { journey_id: journey_id, type: type }
    end

    def cache_key_for_analytics(journey_id:, date_range:)
      pattern = Rails.application.config.journey_suggestions[:cache_patterns][:analytics]
      pattern % { journey_id: journey_id, date_range: date_range }
    end

    def suggestions_cache_ttl
      Rails.application.config.journey_suggestions[:cache_ttl][:suggestions]
    end

    def insights_cache_ttl
      Rails.application.config.journey_suggestions[:cache_ttl][:insights]
    end

    def analytics_cache_ttl
      Rails.application.config.journey_suggestions[:cache_ttl][:analytics]
    end
  end
end

# Include cache helper in relevant classes after they're loaded
Rails.application.config.to_prepare do
  JourneySuggestionEngine.include(JourneySuggestionsCacheHelper) if defined?(JourneySuggestionEngine)
  JourneySuggestionsController.include(JourneySuggestionsCacheHelper) if defined?(JourneySuggestionsController)
end

# Background job scheduling - moved to separate job file
Rails.application.config.after_initialize do
  # Schedule cache warmup job if enabled and available
  if Rails.application.config.journey_suggestions[:cache_warming][:enabled] && defined?(Sidekiq::Cron)
    Sidekiq::Cron::Job.create(
      name: 'Journey Suggestions Cache Warmup',
      cron: '0 */2 * * *', # Every 2 hours
      class: 'JourneySuggestionsCacheWarmupJob'
    )
  end
end