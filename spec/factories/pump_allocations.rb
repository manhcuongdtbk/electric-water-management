FactoryBot.define do
  factory :pump_allocation do
    association :zone
    association :period
    association :unit
    contact_point { nil }
    coefficient { 1 }

    trait :for_contact_point do
      unit { nil }
      association :contact_point, factory: [:contact_point, :residential]
    end
  end
end
