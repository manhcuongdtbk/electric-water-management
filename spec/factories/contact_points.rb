FactoryBot.define do
  factory :contact_point do
    sequence(:name) { |n| "Contact Point #{n}" }
    group_name { "Group A" }
    position { 0 }
    association :organization
  end
end
