FactoryBot.define do
  factory :calculation do
    association :contact_point, factory: [:contact_point, :residential]
    association :period
    total_personnel { 10 }
    residential_standard { 1000 }
    water_pump_standard { 94.5 }
    total_standard { 1094.5 }
    savings_deduction { 50 }
    loss_deduction { 0 }
    division_public_deduction { 100 }
    unit_public_deduction { 0 }
    other_deduction { 0 }
    total_deduction { 150 }
    remaining_standard { 944.5 }
    residential_usage { 800 }
    water_pump_usage { 90 }
    total_usage { 890 }
    surplus { 54.5 }
    deficit { 0 }
    surplus_amount { 0 }
    deficit_amount { 0 }
    calculated_at { Time.current }
  end
end
