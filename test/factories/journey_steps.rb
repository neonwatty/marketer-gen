FactoryBot.define do
  factory :journey_step do
    association :journey
    name { "Welcome Email" }
    description { "Send a welcome email to new users" }
    stage { "awareness" }
    position { 1 }
    content_type { "email" }
    channel { "email" }
    config { { "template" => "welcome", "delay" => "0" } }
    conditions { { "user_status" => "new" } }
    
    trait :sms_step do
      content_type { "sms" }
      channel { "sms" }
      name { "Welcome SMS" }
      stage { "awareness" }
      config { { "message" => "Welcome to our service!", "delay" => "1 hour" } }
    end
    
    trait :delay_step do
      content_type { "delay" }
      channel { "automation" }
      name { "Wait Period" }
      stage { "consideration" }
      config { { "duration" => "24 hours" } }
    end
    
    trait :conditional_step do
      content_type { "conditional" }
      channel { "automation" }
      name { "Check User Engagement" }
      stage { "consideration" }
      conditions { { "email_opened" => true, "clicks" => { "min" => 1 } } }
    end
    
    trait :social_media_step do
      content_type { "social_media" }
      channel { "social_media" }
      name { "Social Media Post" }
      stage { "advocacy" }
      config { { "platform" => "twitter", "content" => "Welcome message", "delay" => "2 hours" } }
    end
    
    factory :sms_journey_step, traits: [:sms_step]
    factory :delay_journey_step, traits: [:delay_step]
    factory :conditional_journey_step, traits: [:conditional_step]
    factory :social_media_journey_step, traits: [:social_media_step]
  end
end