FactoryBot.define do
  factory :ab_test do
    association :campaign
    association :user
    name { "Email Subject Line Test" }
    description { "Testing different subject lines for welcome email" }
    hypothesis { "Personalized subject lines will increase open rates" }
    test_type { "email_open" }
    status { "draft" }
    start_date { 1.day.from_now }
    end_date { 1.week.from_now }
    confidence_level { 95.0 }
    significance_threshold { 5.0 }
    
    trait :running do
      status { "running" }
      start_date { 1.day.ago }
    end
    
    trait :completed do
      status { "completed" }
      start_date { 1.week.ago }
      end_date { 1.day.ago }
    end
    
    trait :with_variants do
      after(:create) do |ab_test|
        journey_a = create(:journey, user: ab_test.user, campaign: ab_test.campaign, name: "Journey A")
        journey_b = create(:journey, user: ab_test.user, campaign: ab_test.campaign, name: "Journey B")
        create(:ab_test_variant, :control, ab_test: ab_test, journey: journey_a)
        create(:ab_test_variant, :variation, ab_test: ab_test, journey: journey_b)
      end
    end
    
    factory :running_ab_test, traits: [:running]
    factory :completed_ab_test, traits: [:completed]
    factory :ab_test_with_variants, traits: [:with_variants]
  end

  factory :ab_test_variant do
    association :ab_test
    name { "Variant A" }
    configuration { 
      {
        "subject_line" => "Welcome to our amazing service!",
        "template" => "welcome_a"
      }
    }
    traffic_percentage { 50.0 }
    is_control { false }
    
    trait :control do
      name { "Control" }
      is_control { true }
      configuration { 
        {
          "subject_line" => "Welcome!",
          "template" => "welcome_control"
        }
      }
    end
    
    trait :variation do
      name { "Variation B" }
      configuration { 
        {
          "subject_line" => "You're in! Let's get started",
          "template" => "welcome_b"
        }
      }
    end
    
    trait :with_results do
      users_assigned { 500 }
      conversions { 50 }
      conversion_rate { 0.1 }
      statistical_significance { 0.95 }
    end
    
    factory :control_variant, traits: [:control]
    factory :variation_variant, traits: [:variation]
    factory :variant_with_results, traits: [:with_results]
  end
end