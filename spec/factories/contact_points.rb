FactoryBot.define do
  factory :contact_point do
    sequence(:name) { |n| "Đầu mối #{n}" }
    contact_point_type { "residential" }
    association :unit
    zone { nil }

    trait :residential do
      contact_point_type { "residential" }
      association :unit
      zone { nil }
    end

    trait :public_type do
      contact_point_type { "public" }
      association :unit
      zone { nil }
    end

    trait :water_pump do
      contact_point_type { "water_pump" }
      unit { nil }
      association :zone
    end

    trait :non_establishment do
      contact_point_type { "non_establishment" }
      unit { nil }
      association :zone
      personnel_count { 5 }
    end

    trait :zone_residential do
      contact_point_type { "residential" }
      unit { nil }
      association :zone
    end
  end
end
