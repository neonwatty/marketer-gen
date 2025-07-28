FactoryBot.define do
  factory :campaign do
    association :user
    association :persona
    name { "Q1 Product Launch Campaign" }
    description { "Launch campaign for our new product line" }
    status { "draft" }
    started_at { 1.week.from_now }
    ended_at { 1.month.from_now }
    campaign_type { "product_launch" }
    goals { "Increase brand awareness and generate qualified leads" }
    target_metrics { 
      {
        "impressions" => 100000,
        "clicks" => 5000,
        "conversions" => 500,
        "cost_per_acquisition" => 100
      }
    }
    
    trait :active do
      status { "active" }
      started_at { 1.day.ago }
    end
    
    trait :completed do
      status { "completed" }
      started_at { 1.month.ago }
      ended_at { 1.week.ago }
    end
    
    trait :with_high_metrics do
      target_metrics { 
        {
          "impressions" => 500000,
          "clicks" => 25000,
          "conversions" => 2500,
          "cost_per_acquisition" => 40
        }
      }
    end
    
    trait :email_focused do
      campaign_type { "email_nurture" }
      goals { "Improve email engagement and grow subscriber list" }
    end
    
    trait :social_media_focused do
      campaign_type { "social_media" }
      goals { "Increase social media engagement and brand awareness" }
    end
    
    factory :active_campaign, traits: [:active]
    factory :completed_campaign, traits: [:completed]
    factory :high_metrics_campaign, traits: [:with_high_metrics]
    factory :email_campaign, traits: [:email_focused]
    factory :social_media_campaign, traits: [:social_media_focused]
  end
end