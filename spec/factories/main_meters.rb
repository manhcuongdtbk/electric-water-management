FactoryBot.define do
  factory :main_meter do
    sequence(:name) { |n| "Khu vuc DH tong #{n}" }
    sequence(:code) { |n| "MM-#{n}" }
    position { 0 }
  end
end
