FactoryBot.define do
  factory :pump_station do
    sequence(:name) { |n| "Tram bom #{n}" }
    association :zone
  end
end
