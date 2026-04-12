FactoryBot.define do
  factory :monthly_calculation do
    association :contact_point
    association :monthly_period
    total_personnel { 40 }
    rank1_kw { 1140 }
    rank2_kw { 2200 }
    rank3_kw { 3050 }
    rank4_kw { 2600 }
    rank5_kw { 0 }
    rank6_kw { 330 }
    rank7_kw { 0 }
    water_pump_standard_kw { 378 }
    water_pump_actual_kw { 350 }
    total_standard_kw { 9320 }
    savings_deduction_kw { 466 }
    loss_deduction_kw { 93 }
    division_public_deduction_kw { 932 }
    unit_public_deduction_kw { 466 }
    other_deduction_kw { 0 }
    total_deduction_kw { 1957 }
    remaining_standard_kw { 7363 }
    meter_usage_kw { 7100 }
    total_usage_kw { 7450 }
    over_under_kw { -87 }
    unit_price { 2000 }
    total_amount { 14_900_000 }
  end
end
