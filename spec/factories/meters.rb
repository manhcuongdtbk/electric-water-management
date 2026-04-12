FactoryBot.define do
  factory :meter do
    sequence(:name) { |n| "Meter #{n}" }
    sequence(:serial_number) { |n| "SN#{n.to_s.rjust(6, '0')}" }
    meter_type { :normal }
    notes { nil }
    position { 0 }
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
    end
  end
end
