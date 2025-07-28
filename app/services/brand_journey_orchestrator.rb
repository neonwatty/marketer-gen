class BrandJourneyOrchestrator
  # Simple facade for accessing brand-journey integration features
  
  def self.generate_brand_aware_suggestions(journey:, user: nil, **options)
    service = Journey::BrandIntegrationService.new(journey: journey, user: user)
    service.orchestrate_brand_journey_flow(operation: :generate_suggestions, **options)
  end
  
  def self.validate_journey_brand_compliance(journey:, user: nil, **options)
    service = Journey::BrandIntegrationService.new(journey: journey, user: user)
    service.orchestrate_brand_journey_flow(operation: :validate_content, **options)
  end
  
  def self.enhance_journey_compliance(journey:, user: nil, **options)
    service = Journey::BrandIntegrationService.new(journey: journey, user: user)
    service.orchestrate_brand_journey_flow(operation: :auto_enhance_compliance, **options)
  end
  
  def self.analyze_brand_performance(journey:, user: nil, **options)
    service = Journey::BrandIntegrationService.new(journey: journey, user: user)
    service.orchestrate_brand_journey_flow(operation: :analyze_brand_performance, **options)
  end
  
  def self.sync_with_brand_updates(journey:, user: nil, **options)
    service = Journey::BrandIntegrationService.new(journey: journey, user: user)
    service.orchestrate_brand_journey_flow(operation: :sync_brand_updates, **options)
  end
  
  def self.check_integration_health(journey:, user: nil)
    service = Journey::BrandIntegrationService.new(journey: journey, user: user)
    service.integration_health_check
  end
  
  # Convenience methods for common operations
  def self.quick_compliance_check(journey:)
    return { score: 1.0, message: 'No brand associated' } unless journey.brand.present?
    
    scores = journey.journey_steps.map(&:quick_compliance_score)
    average_score = scores.sum / scores.length
    
    {
      score: average_score.round(3),
      compliant_steps: scores.count { |s| s >= 0.7 },
      total_steps: scores.length,
      compliance_rate: (scores.count { |s| s >= 0.7 }.to_f / scores.length * 100).round(1)
    }
  end
  
  def self.brand_integration_status(journey:)
    return { integrated: false, reason: 'No brand associated' } unless journey.brand.present?
    
    brand = journey.brand
    integration_indicators = {
      has_messaging_framework: brand.messaging_framework.present?,
      has_active_guidelines: brand.brand_guidelines.active.any?,
      has_voice_attributes: brand.brand_voice_attributes.present?,
      recent_compliance_checks: journey.journey_insights.brand_compliance.recent(7).any?
    }
    
    integration_score = integration_indicators.values.count(true).to_f / integration_indicators.length
    
    {
      integrated: integration_score >= 0.5,
      integration_score: integration_score.round(2),
      indicators: integration_indicators,
      status: integration_score >= 0.8 ? 'fully_integrated' : 
              integration_score >= 0.5 ? 'partially_integrated' : 'not_integrated'
    }
  end
end