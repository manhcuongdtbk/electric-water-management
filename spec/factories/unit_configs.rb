FactoryBot.define do
  factory :unit_config do
    association :organization
    association :monthly_period
    savings_rate { 0.05 }
    division_public_rate { 0.10 }
    unit_public_rate { 0.05 }
    other_deduction_type { :fixed_kw }
    other_deduction_value { 0 }
    electricity_supply_kw { nil }
  end
end
