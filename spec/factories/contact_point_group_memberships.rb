FactoryBot.define do
  factory :contact_point_group_membership do
    association :contact_point_group
    association :contact_point
  end
end
