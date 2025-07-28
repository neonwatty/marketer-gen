FactoryBot.define do
  factory :journey_template do
    association :user
    name { "Customer Onboarding Template" }
    description { "A template for onboarding new customers" }
    category { "onboarding" }
    template_data { 
      {
        "steps" => [
          {
            "title" => "Welcome Email",
            "type" => "email",
            "config" => { "template" => "welcome" }
          },
          {
            "title" => "Follow Up",
            "type" => "email", 
            "config" => { "template" => "followup", "delay" => "3 days" }
          }
        ]
      }
    }
    is_public { false }
    version { "1.0.0" }
    
    trait :public_template do
      is_public { true }
    end
    
    trait :nurture_template do
      name { "Lead Nurturing Template" }
      category { "nurture" }
      template_data { 
        {
          "steps" => [
            {
              "title" => "Educational Content",
              "type" => "email",
              "config" => { "template" => "education" }
            },
            {
              "title" => "Product Demo",
              "type" => "email",
              "config" => { "template" => "demo", "delay" => "1 week" }
            }
          ]
        }
      }
    end
    
    trait :retention_template do
      name { "Customer Retention Template" }
      category { "retention" }
      template_data { 
        {
          "steps" => [
            {
              "title" => "Check-in Email",
              "type" => "email",
              "config" => { "template" => "checkin" }
            },
            {
              "title" => "Feedback Request",
              "type" => "email",
              "config" => { "template" => "feedback", "delay" => "2 weeks" }
            }
          ]
        }
      }
    end
    
    factory :public_journey_template, traits: [:public_template]
    factory :nurture_journey_template, traits: [:nurture_template]
    factory :retention_journey_template, traits: [:retention_template]
  end
end