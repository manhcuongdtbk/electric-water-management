FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    level { :unit }
    position { 0 }

    trait :division do
      level { :division }
      parent { nil }
      sequence(:name) { |n| "Division #{n}" }
    end

    trait :unit do
      level { :unit }
      association :parent, factory: [ :organization, :division ]
    end
  end
end
