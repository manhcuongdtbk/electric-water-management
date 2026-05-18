FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    display_name { "Người dùng" }
    role { "technician" }
    password { "Abc@1234" }
    password_confirmation { "Abc@1234" }
    force_password_change { false }
    default_account { false }

    trait :system_admin do
      role { "system_admin" }
    end

    trait :unit_admin do
      role { "unit_admin" }
      association :unit
    end

    trait :commander do
      role { "commander" }
      association :unit
    end

    trait :default_account do
      default_account { true }
    end
  end
end
