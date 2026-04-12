FactoryBot.define do
  factory :meter_reading do
    association :meter
    association :monthly_period
    reading_start { 1000 }
    reading_end { 1250 }
    consumption { 250 }
  end
end
