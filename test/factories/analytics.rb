FactoryBot.define do
  factory :journey_analytics do
    association :journey
    association :campaign
    association :user
    period_start { 1.day.ago }
    period_end { Time.current }
    total_executions { 1000 }
    completed_executions { 750 }
    abandoned_executions { 100 } # 750 + 100 = 850 < 1000 
    conversion_rate { 75.0 }
    engagement_score { 85.0 }
    average_completion_time { 3600.0 } # 1 hour in seconds
    metrics { 
      {
        "email_open_rate" => 0.65,
        "click_through_rate" => 0.25,
        "bounce_rate" => 0.05
      }
    }
    metadata { { "campaign_type" => "email", "segment" => "all_users" } }
    
    trait :high_performance do
      conversion_rate { 85.0 }
      engagement_score { 95.0 }
      completed_executions { 850 }
      abandoned_executions { 50 } # 850 + 50 = 900 < 1000
    end
    
    trait :low_performance do
      conversion_rate { 45.0 }
      engagement_score { 55.0 }
      completed_executions { 450 }
      abandoned_executions { 300 } # 450 + 300 = 750 < 1000
    end
  end

  factory :conversion_funnel do
    association :journey
    funnel_data { 
      {
        "steps" => [
          { "name" => "Email Sent", "count" => 1000, "conversion_rate" => 1.0 },
          { "name" => "Email Opened", "count" => 600, "conversion_rate" => 0.6 },
          { "name" => "Link Clicked", "count" => 200, "conversion_rate" => 0.33 },
          { "name" => "Form Submitted", "count" => 50, "conversion_rate" => 0.25 }
        ]
      }
    }
    total_users { 1000 }
    final_conversions { 50 }
    overall_conversion_rate { 0.05 }
    
    trait :high_converting do
      funnel_data { 
        {
          "steps" => [
            { "name" => "Email Sent", "count" => 1000, "conversion_rate" => 1.0 },
            { "name" => "Email Opened", "count" => 800, "conversion_rate" => 0.8 },
            { "name" => "Link Clicked", "count" => 400, "conversion_rate" => 0.5 },
            { "name" => "Form Submitted", "count" => 200, "conversion_rate" => 0.5 }
          ]
        }
      }
      final_conversions { 200 }
      overall_conversion_rate { 0.2 }
    end
  end

  factory :journey_metrics do
    association :journey
    metric_name { "email_open_rate" }
    metric_value { 0.65 }
    measurement_date { Date.current }
    metadata { { "campaign_id" => "123", "segment" => "all_users" } }
    
    trait :click_rate do
      metric_name { "email_click_rate" }
      metric_value { 0.25 }
    end
    
    trait :conversion_rate do
      metric_name { "conversion_rate" }
      metric_value { 0.05 }
    end
    
    trait :unsubscribe_rate do
      metric_name { "unsubscribe_rate" }
      metric_value { 0.01 }
    end
  end
end