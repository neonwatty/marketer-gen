FactoryBot.define do
  factory :persona do
    association :user
    name { "Tech-Savvy Millennial" }
    description { "Young professionals who are early adopters of technology" }
    demographics { 
      {
        "age_range" => "25-35",
        "income" => "high",
        "education" => "college"
      }
    }
    behaviors {
      {
        "tech_adoption" => "early",
        "communication_preference" => "email",
        "shopping_habits" => "online"
      }
    }
    preferences {
      {
        "channels" => ["email", "social_media"],
        "content_types" => ["video", "articles"],
        "interests" => ["technology", "innovation", "productivity"]
      }
    }
    
    trait :budget_conscious do
      name { "Budget-Conscious Consumer" }
      description { "Price-sensitive customers looking for value" }
      demographics { 
        {
          "age_range" => "30-50",
          "income" => "medium",
          "family_status" => "married"
        }
      }
      behaviors {
        {
          "price_sensitivity" => "high",
          "communication_preference" => "sms",
          "shopping_habits" => "comparison"
        }
      }
      preferences {
        {
          "channels" => ["sms", "email"],
          "interests" => ["savings", "deals", "family"]
        }
      }
    end
    
    trait :enterprise_buyer do
      name { "Enterprise Decision Maker" }
      description { "B2B buyers focused on business solutions" }
      attributes { 
        {
          "role" => "decision_maker",
          "company_size" => "enterprise",
          "industry" => "technology",
          "communication_preference" => "email",
          "interests" => ["efficiency", "ROI", "scalability"]
        }
      }
    end
    
    trait :young_professional do
      name { "Young Professional" }
      description { "Recent graduates starting their careers" }
      attributes { 
        {
          "age_range" => "22-28",
          "income" => "low",
          "career_stage" => "early",
          "communication_preference" => "social_media",
          "interests" => ["career_growth", "networking", "learning"]
        }
      }
    end
    
    factory :budget_conscious_persona, traits: [:budget_conscious]
    factory :enterprise_buyer_persona, traits: [:enterprise_buyer]
    factory :young_professional_persona, traits: [:young_professional]
  end
end