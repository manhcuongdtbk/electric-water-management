FactoryBot.define do
  factory :pump_station_assignment do
    association :pump_station
    association :organization
  end
end
