FactoryBot.define do
  factory :pump_allocation do
    association :zone
    association :period
    unit { association(:unit, zone: zone) }
    contact_point { nil }
    coefficient { 1 }

    trait :for_contact_point do
      unit { nil }
      contact_point do
        cp_unit = association(:unit, zone: zone)
        association(:contact_point, :residential, unit: cp_unit, zone: nil)
      end
    end
  end
end
