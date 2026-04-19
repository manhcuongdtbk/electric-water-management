FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password1!" }
    password_confirmation { "Password1!" }
    full_name { "Nguyen Van A" }
    role { :admin_unit }
    force_password_change { false }
    association :organization, strategy: :create

    trait :admin_level1 do
      role { :admin_level1 }
    end

    trait :admin_unit do
      role { :admin_unit }
    end

    trait :commander do
      role { :commander }
    end

    trait :tech do
      role { :tech }
    end

    trait :locked do
      locked_at { Time.current }
      failed_attempts { 5 }
    end

    trait :force_change_password do
      force_password_change { true }
    end
  end
end
