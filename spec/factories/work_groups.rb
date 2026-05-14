FactoryBot.define do
  factory :work_group do
    sequence(:name) { |n| "Nhom cong tac #{n}" }
    personnel_count { 10 }
    association :owner_organization, factory: %i[organization unit]
  end
end
