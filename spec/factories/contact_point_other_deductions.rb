FactoryBot.define do
  factory :contact_point_other_deduction do
    association :contact_point
    association :monthly_period
    other_type { :fixed_kw }
    other_value { 0 }
  end
end
