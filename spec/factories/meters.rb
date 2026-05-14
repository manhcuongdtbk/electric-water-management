FactoryBot.define do
  factory :meter do
    sequence(:name) { |n| "Meter #{n}" }
    meter_type { :normal }
    association :organization

    trait :normal do
      meter_type { :normal }
      association :contact_point
    end

    trait :public_meter do
      meter_type { :public_meter }
    end

    trait :pump_station do
      meter_type { :pump_station }
      contact_point { nil }
      pump_station { association(:pump_station) }
    end

    trait :no_loss do
      meter_type { :normal }
      no_loss { true }
      association :contact_point
    end
  end
end
