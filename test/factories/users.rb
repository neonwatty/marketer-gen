FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }
    full_name { "John Doe" }
    role { 0 } # 0 = user, 1 = admin
    
    trait :admin do
      role { 1 } # admin role
      sequence(:email_address) { |n| "admin#{n}@example.com" }
    end
    
    trait :locked do
      locked_at { 1.hour.ago }
    end
    
    trait :suspended do
      suspended { true }
      suspended_at { 1.day.ago }
      suspension_reason { "Testing suspension" }
    end
  end
end