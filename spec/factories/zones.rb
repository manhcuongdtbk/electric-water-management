FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Khu vực #{n}" }

    trait :with_manager do
      association :manager_organization, factory: %i[organization unit]
    end
  end
end
