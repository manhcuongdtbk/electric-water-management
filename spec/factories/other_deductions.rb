FactoryBot.define do
  factory :other_deduction do
    association :contact_point, factory: [:contact_point, :residential]
    association :period
    other_type { "fixed" }
    other_value { 0 }
  end
end
