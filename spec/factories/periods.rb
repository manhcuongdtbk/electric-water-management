FactoryBot.define do
  factory :period do
    sequence(:year) { |n| 2020 + (n / 12) }
    sequence(:month) { |n| (n % 12) + 1 }
    unit_price { 3500 }
    closed { true }
    savings_rate { 5 }
    division_public_rate { 10 }
    water_pump_standard { 9.45 }
  end
end
