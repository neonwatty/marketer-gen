FactoryBot.define do
  factory :ab_test_metric do
    association :ab_test
    association :ab_test_variant
    association :user
    
    metric_name { "impression" }
    metric_value { 1 }
    visitor_id { "visitor_#{rand(1000..9999)}" }
    session_id { "session_#{rand(1000..9999)}" }
    timestamp { Time.current }
    metadata do
      {
        "page_url" => "/test-page",
        "user_agent" => "Test User Agent",
        "referrer" => "https://example.com",
        "device_type" => "desktop",
        "location" => "US"
      }
    end
  end

  factory :ab_test_result do
    association :ab_test
    association :ab_test_variant
    association :user
    
    metric_name { "conversion_rate" }
    metric_value { 0.15 }
    sample_size { 1000 }
    confidence_level { 0.95 }
    statistical_significance { true }
    p_value { 0.05 }
    confidence_interval_lower { 0.12 }
    confidence_interval_upper { 0.18 }
    recorded_at { Time.current }
    metadata do
      {
        "analysis_type" => "frequentist",
        "effect_size" => 1.5,
        "power" => 0.8,
        "duration_days" => 14
      }
    end
  end

  factory :ab_test_configuration do
    association :ab_test
    association :user
    
    config_type { "advanced" }
    traffic_rules do
      {
        "geographic_restrictions" => ["US", "CA", "UK"],
        "device_targeting" => ["desktop", "mobile"],
        "user_segments" => ["new_users", "returning_users"],
        "exclusion_rules" => ["bot_traffic", "internal_users"]
      }
    end
    success_criteria do
      {
        "primary_metric" => "conversion_rate",
        "secondary_metrics" => ["engagement_score", "time_on_page"],
        "minimum_confidence" => 95,
        "minimum_effect_size" => 5.0
      }
    end
    advanced_settings do
      {
        "sequential_testing" => true,
        "bayesian_analysis" => false,
        "early_stopping" => true,
        "power_analysis" => 0.8
      }
    end
  end

  factory :ab_test_template do
    association :user
    
    name { "Standard A/B Test Template" }
    description { "Template for standard A/B testing" }
    template_type { "conversion_optimization" }
    template_config do
      {
        "default_metrics" => ["conversion_rate", "click_through_rate"],
        "default_duration" => 14,
        "default_sample_size" => 1000,
        "default_confidence" => 0.95
      }
    end
    is_public { false }
  end

  factory :ab_test_recommendation do
    association :ab_test
    
    recommendation_type { "optimization" }
    content { "Recommendation to optimize test performance" }
    confidence_score { 0.85 }
    status { "active" }
    metadata do
      {
        "recommendation_source" => "ai_analysis",
        "impact_estimate" => "high",
        "implementation_effort" => "medium"
      }
    end
  end
end