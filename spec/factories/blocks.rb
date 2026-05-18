FactoryBot.define do
  factory :block do
    sequence(:name) { |n| "Khối #{n}" }
    association :unit
  end
end
