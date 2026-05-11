FactoryBot.define do
  factory :main_meter_reading do
    association :main_meter
    association :monthly_period
    electricity_supply_kw { 1000 }
  end
end
