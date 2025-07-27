class JourneySuggestionsCacheWarmupJob < ApplicationJob
  queue_as :low_priority

  def perform
    return unless cache_warming_enabled?

    Rails.logger.info "Starting journey suggestions cache warmup"
    
    # Warm cache for active journeys with recent activity
    active_journeys = Journey.published
                            .joins(:journey_executions)
                            .where('journey_executions.updated_at > ?', 7.days.ago)
                            .distinct
                            .limit(batch_size)

    active_journeys.find_each do |journey|
      warm_journey_cache(journey)
    end

    Rails.logger.info "Completed journey suggestions cache warmup for #{active_journeys.count} journeys"
  end

  private

  def cache_warming_enabled?
    Rails.application.config.journey_suggestions[:cache_warming][:enabled]
  end

  def batch_size
    Rails.application.config.journey_suggestions[:cache_warming][:batch_size]
  end

  def warm_journey_cache(journey)
    return unless journey.user

    # Warm suggestions cache for common scenarios
    common_providers = [:openai, :anthropic]
    common_filters = [
      {},
      { stage: 'awareness' },
      { stage: 'conversion' },
      { content_type: 'email' }
    ]

    common_providers.each do |provider|
      common_filters.each do |filters|
        begin
          engine = JourneySuggestionEngine.new(
            journey: journey,
            user: journey.user,
            provider: provider
          )
          
          # Generate suggestions to populate cache
          engine.generate_suggestions(filters)
          
          sleep(0.1) # Rate limiting
        rescue => e
          Rails.logger.warn "Cache warmup failed for journey #{journey.id} with provider #{provider}: #{e.message}"
        end
      end
    end
  end
end