FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Khu vực #{n}" }
  end
end
