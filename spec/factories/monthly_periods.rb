FactoryBot.define do
  factory :monthly_period do
    # Sequence encodes year+month: n=1 → 2026/01, n=13 → 2027/01, etc.
    sequence(:year)  { |n| 2026 + ((n - 1) / 12) }
    sequence(:month) { |n| ((n - 1) % 12) + 1 }
    unit_price { 2000 }
    locked { false }

    trait :locked do
      locked { true }
      locked_at { Time.current }
      association :locked_by, factory: :user
    end
  end
end
