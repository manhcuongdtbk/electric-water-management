FactoryBot.define do
  factory :non_establishment_snapshot do
    association :contact_point, factory: [:contact_point, :non_establishment]
    association :period
    personnel_count { 5 }
  end
end
