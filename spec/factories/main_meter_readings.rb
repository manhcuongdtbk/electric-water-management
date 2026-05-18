FactoryBot.define do
  factory :main_meter_reading do
    association :main_meter
    association :period
    usage { 1000 }
  end
end
