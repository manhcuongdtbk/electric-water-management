FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    level { :unit }
    association :zone

    trait :division do
      level { :division }
      parent { nil }
      zone { nil }
      sequence(:name) { |n| "Division #{n}" }
    end

    trait :unit do
      level { :unit }
      association :parent, factory: [ :organization, :division ]
      association :zone
    end
  end
end
