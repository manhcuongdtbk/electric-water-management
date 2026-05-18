FactoryBot.define do
  factory :meter_reading do
    association :meter
    association :period
    reading_start { 0 }
    reading_end { 100 }
    no_loss { false }
  end
end
