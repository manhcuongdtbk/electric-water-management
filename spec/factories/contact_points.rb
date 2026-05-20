FactoryBot.define do
  factory :contact_point do
    sequence(:name) { |n| "Đầu mối #{n}" }
    contact_point_type { "residential" }
    association :unit
    zone { nil }
    # 1 người để đầu mối sinh hoạt qua validation tạo mới; key 0 không trùng rank id thật
    initial_personnel_counts { { 0 => 1 } }

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
