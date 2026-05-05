FactoryBot.define do
  factory :pump_station_assignment do
    association :pump_station
    association :organization

    trait :fixed do
      transient do
        percentage { 30 }
      end
      fixed_pump_percentage { percentage }
    end
  end
end
