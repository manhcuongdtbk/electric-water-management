FactoryBot.define do
  factory :contact_point_group do
    sequence(:name) { |n| "Nhóm #{n}" }
    association :organization
  end
end
