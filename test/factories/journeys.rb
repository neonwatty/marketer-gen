FactoryBot.define do
  factory :journey do
    association :user
    name { "Customer Onboarding Journey" }
    description { "A comprehensive onboarding journey for new customers" }
    status { "draft" }
    campaign_type { "customer_retention" }
    metadata { { "channel" => "email", "goal" => "activation" } }
    
    trait :published do
      status { "published" }
    end
    
    trait :active do
      status { "active" }
    end
    
    trait :completed do
      status { "completed" }
    end
    
    trait :with_steps do
      after(:create) do |journey|
        create_list(:journey_step, 3, journey: journey)
      end
    end
    
    trait :with_campaign do
      association :campaign
    end
    
    factory :published_journey, traits: [:published]
    factory :active_journey, traits: [:active]
    factory :journey_with_steps, traits: [:with_steps]
  end
end