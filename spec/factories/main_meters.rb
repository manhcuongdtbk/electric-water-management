FactoryBot.define do
  factory :main_meter do
    sequence(:name) { |n| "Khu vuc DH tong #{n}" }
    association :zone
  end
end
