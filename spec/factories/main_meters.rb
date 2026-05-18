FactoryBot.define do
  factory :main_meter do
    sequence(:name) { |n| "Công tơ tổng #{n}" }
    association :zone
  end
end
