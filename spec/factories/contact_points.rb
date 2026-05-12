FactoryBot.define do
  factory :contact_point do
    sequence(:name) { |n| "Contact Point #{n}" }
    group_name { "Group A" }
    position { 0 }
    contact_point_type { :residential }
    association :organization

    trait :residential do
      contact_point_type { :residential }
    end

    trait :communal do
      contact_point_type { :communal }
    end
  end
end
