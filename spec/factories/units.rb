FactoryBot.define do
  factory :unit do
    sequence(:name) { |n| "Đơn vị #{n}" }
    association :zone
  end
end
